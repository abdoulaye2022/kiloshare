<?php

declare(strict_types=1);

/**
 * Test d'intégration pour le système Cloudinary KiloShare
 * 
 * Ce script valide que tous les composants sont correctement installés
 * et configurés pour fonctionner ensemble.
 */

require __DIR__ . '/../vendor/autoload.php';

use KiloShare\Config\Database;
use KiloShare\Config\Config;
use KiloShare\Services\CloudinaryService;

// Colors for console output
define('GREEN', "\033[32m");
define('RED', "\033[31m");
define('YELLOW', "\033[33m");
define('BLUE', "\033[34m");
define('RESET', "\033[0m");

class CloudinaryIntegrationTest
{
    private array $results = [];
    private int $testCount = 0;
    private int $passedTests = 0;

    public function run(): void
    {
        echo BLUE . "🧪 KiloShare Cloudinary Integration Test\n" . RESET;
        echo str_repeat("=", 50) . "\n\n";

        $this->testEnvironmentVariables();
        $this->testDatabaseConnection();
        $this->testDatabaseTables();
        $this->testCloudinaryService();
        $this->testFilesystemPermissions();
        $this->testCronScripts();
        $this->testMonitoringEndpoints();

        $this->displayResults();
    }

    private function testEnvironmentVariables(): void
    {
        echo "🔧 Testing environment variables...\n";

        $requiredVars = [
            'CLOUDINARY_CLOUD_NAME',
            'CLOUDINARY_API_KEY', 
            'CLOUDINARY_API_SECRET',
            'CLOUDINARY_UPLOAD_PRESET'
        ];

        foreach ($requiredVars as $var) {
            $value = $_ENV[$var] ?? null;
            $this->assert(
                !empty($value),
                "Environment variable $var is set",
                "Missing required environment variable: $var"
            );
        }

        $this->assert(
            !empty($_ENV['CLOUDINARY_STORAGE_THRESHOLD'] ?? ''),
            "Storage threshold is configured",
            "Missing CLOUDINARY_STORAGE_THRESHOLD"
        );

        echo "\n";
    }

    private function testDatabaseConnection(): void
    {
        echo "🗄️  Testing database connection...\n";

        try {
            $pdo = Database::getConnection();
            $this->assert(
                $pdo instanceof PDO,
                "Database connection established",
                "Failed to connect to database"
            );

            // Test basic query
            $stmt = $pdo->query("SELECT 1");
            $this->assert(
                $stmt !== false,
                "Database query execution works",
                "Failed to execute basic query"
            );

        } catch (Exception $e) {
            $this->assert(
                false,
                "Database connection test",
                "Database connection failed: " . $e->getMessage()
            );
        }

        echo "\n";
    }

    private function testDatabaseTables(): void
    {
        echo "📋 Testing database tables...\n";

        try {
            $pdo = Database::getConnection();
            
            $requiredTables = [
                'image_uploads',
                'cloudinary_usage_stats',
                'cloudinary_cleanup_log',
                'cloudinary_alerts'
            ];

            foreach ($requiredTables as $table) {
                $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
                $stmt->execute([$table]);
                $exists = $stmt->fetch() !== false;
                
                $this->assert(
                    $exists,
                    "Table '$table' exists",
                    "Missing required table: $table"
                );
            }

            // Test image_uploads table structure
            $stmt = $pdo->query("DESCRIBE image_uploads");
            $columns = $stmt->fetchAll(PDO::FETCH_COLUMN);
            
            $requiredColumns = ['id', 'cloudinary_public_id', 'user_id', 'image_type', 'file_size'];
            foreach ($requiredColumns as $column) {
                $this->assert(
                    in_array($column, $columns),
                    "Column '$column' exists in image_uploads",
                    "Missing column '$column' in image_uploads table"
                );
            }

        } catch (Exception $e) {
            $this->assert(
                false,
                "Database tables test",
                "Database tables test failed: " . $e->getMessage()
            );
        }

        echo "\n";
    }

    private function testCloudinaryService(): void
    {
        echo "☁️  Testing Cloudinary service...\n";

        try {
            $pdo = Database::getConnection();
            $logger = new \Monolog\Logger('test');
            $service = new CloudinaryService($pdo, $logger);

            // Test service instantiation
            $this->assert(
                $service instanceof CloudinaryService,
                "CloudinaryService can be instantiated",
                "Failed to create CloudinaryService instance"
            );

            // Test configuration loading
            $this->assert(
                method_exists($service, 'getUsageStats'),
                "CloudinaryService has required methods",
                "CloudinaryService missing expected methods"
            );

            // Test quota check (should not throw)
            try {
                $quotaStatus = $service->checkQuotaStatus();
                $this->assert(
                    is_array($quotaStatus),
                    "Quota status check returns array",
                    "Quota status check failed"
                );
            } catch (Exception $e) {
                $this->assert(
                    false,
                    "Quota status check",
                    "Quota check failed: " . $e->getMessage()
                );
            }

        } catch (Exception $e) {
            $this->assert(
                false,
                "CloudinaryService test",
                "CloudinaryService test failed: " . $e->getMessage()
            );
        }

        echo "\n";
    }

    private function testFilesystemPermissions(): void
    {
        echo "📁 Testing filesystem permissions...\n";

        $directories = [
            __DIR__ . '/../logs',
            __DIR__ . '/../scripts',
            __DIR__ . '/../temp'
        ];

        foreach ($directories as $dir) {
            if (!is_dir($dir)) {
                @mkdir($dir, 0755, true);
            }

            $this->assert(
                is_dir($dir),
                "Directory '$dir' exists",
                "Missing directory: $dir"
            );

            $this->assert(
                is_writable($dir),
                "Directory '$dir' is writable",
                "Directory not writable: $dir"
            );
        }

        // Test log file creation
        $logFile = __DIR__ . '/../logs/test.log';
        $canWrite = @file_put_contents($logFile, "test\n") !== false;
        
        $this->assert(
            $canWrite,
            "Can write to logs directory",
            "Cannot write to logs directory"
        );

        if (file_exists($logFile)) {
            @unlink($logFile);
        }

        echo "\n";
    }

    private function testCronScripts(): void
    {
        echo "⏰ Testing cron scripts...\n";

        $scriptsDir = __DIR__ . '/../scripts';
        
        $requiredScripts = [
            'cloudinary_cleanup.php',
            'setup_cron.sh',
            'remove_cron.sh'
        ];

        foreach ($requiredScripts as $script) {
            $scriptPath = $scriptsDir . '/' . $script;
            
            $this->assert(
                file_exists($scriptPath),
                "Script '$script' exists",
                "Missing script: $script"
            );

            $this->assert(
                is_executable($scriptPath) || pathinfo($script, PATHINFO_EXTENSION) === 'php',
                "Script '$script' has correct permissions",
                "Script not executable: $script"
            );
        }

        // Test PHP syntax of cleanup script
        $cleanupScript = $scriptsDir . '/cloudinary_cleanup.php';
        if (file_exists($cleanupScript)) {
            $output = shell_exec("php -l '$cleanupScript' 2>&1");
            $syntaxOk = strpos($output, 'No syntax errors') !== false;
            
            $this->assert(
                $syntaxOk,
                "Cleanup script has valid PHP syntax",
                "Cleanup script has syntax errors: " . trim($output)
            );
        }

        echo "\n";
    }

    private function testMonitoringEndpoints(): void
    {
        echo "🔍 Testing monitoring system...\n";

        // Test controller exists
        $controllerFile = __DIR__ . '/../src/Controllers/CloudinaryMonitoringController.php';
        
        $this->assert(
            file_exists($controllerFile),
            "CloudinaryMonitoringController exists",
            "Missing CloudinaryMonitoringController file"
        );

        // Test Flutter dashboard widget exists
        $flutterFile = __DIR__ . '/../../mobile/lib/modules/admin/widgets/cloudinary_monitoring_dashboard.dart';
        
        $this->assert(
            file_exists($flutterFile),
            "Flutter monitoring dashboard exists",
            "Missing Flutter monitoring dashboard"
        );

        // Test routes configuration
        $routesFile = __DIR__ . '/../src/Config/routes.php';
        if (file_exists($routesFile)) {
            $routesContent = file_get_contents($routesFile);
            $hasCloudinaryRoutes = strpos($routesContent, '/cloudinary') !== false;
            
            $this->assert(
                $hasCloudinaryRoutes,
                "Cloudinary monitoring routes are configured",
                "Missing Cloudinary monitoring routes in routes.php"
            );
        }

        echo "\n";
    }

    private function assert(bool $condition, string $successMessage, string $errorMessage): void
    {
        $this->testCount++;
        
        if ($condition) {
            echo GREEN . "✅ $successMessage\n" . RESET;
            $this->passedTests++;
            $this->results[] = ['status' => 'PASS', 'message' => $successMessage];
        } else {
            echo RED . "❌ $errorMessage\n" . RESET;
            $this->results[] = ['status' => 'FAIL', 'message' => $errorMessage];
        }
    }

    private function displayResults(): void
    {
        echo str_repeat("=", 50) . "\n";
        echo BLUE . "📊 Test Results Summary\n" . RESET;
        echo str_repeat("=", 50) . "\n";

        $failedTests = $this->testCount - $this->passedTests;
        $successRate = round(($this->passedTests / $this->testCount) * 100, 1);

        echo "Total tests: {$this->testCount}\n";
        echo GREEN . "Passed: {$this->passedTests}\n" . RESET;
        echo ($failedTests > 0 ? RED : GREEN) . "Failed: $failedTests\n" . RESET;
        echo "Success rate: $successRate%\n\n";

        if ($failedTests === 0) {
            echo GREEN . "🎉 All tests passed! Cloudinary integration is ready.\n" . RESET;
            echo "\nNext steps:\n";
            echo "1. Run database migration: mysql < migrations/add_cloudinary_image_system.sql\n";
            echo "2. Install cron jobs: ./scripts/setup_cron.sh\n";
            echo "3. Test image upload in your application\n";
        } else {
            echo RED . "⚠️  Some tests failed. Please review the errors above.\n" . RESET;
            echo "\nFailed tests:\n";
            foreach ($this->results as $result) {
                if ($result['status'] === 'FAIL') {
                    echo RED . "- {$result['message']}\n" . RESET;
                }
            }
        }

        echo "\n" . str_repeat("=", 50) . "\n";
    }
}

// Load environment variables
if (file_exists(__DIR__ . '/../.env')) {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
    $dotenv->load();
}

// Run the integration test
$test = new CloudinaryIntegrationTest();
$test->run();