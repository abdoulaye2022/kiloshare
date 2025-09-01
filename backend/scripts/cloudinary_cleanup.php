<?php

declare(strict_types=1);

use DI\ContainerBuilder;
use KiloShare\Services\CloudinaryService;
use KiloShare\Config\Database;
use KiloShare\Config\Config;

require __DIR__ . '/../vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

// Build DI container with minimal dependencies for cron job
$containerBuilder = new ContainerBuilder();

$containerBuilder->addDefinitions([
    // Database PDO
    PDO::class => function () {
        return Database::getConnection();
    },
    
    // Logger
    Psr\Log\LoggerInterface::class => function () {
        $logger = new \Monolog\Logger('cloudinary-cleanup');
        $handler = new \Monolog\Handler\StreamHandler(__DIR__ . '/../logs/cloudinary_cleanup.log', \Monolog\Level::Info);
        $formatter = new \Monolog\Formatter\LineFormatter(
            "[%datetime%] %channel%.%level_name%: %message% %context% %extra%\n"
        );
        $handler->setFormatter($formatter);
        $logger->pushHandler($handler);
        return $logger;
    },
    
    // Cloudinary Service
    \KiloShare\Services\CloudinaryService::class => function ($container) {
        return new \KiloShare\Services\CloudinaryService(
            $container->get(PDO::class),
            $container->get(Psr\Log\LoggerInterface::class)
        );
    },
]);

$container = $containerBuilder->build();

function displayUsage(): void {
    echo "Usage: php cloudinary_cleanup.php [command] [options]\n\n";
    echo "Commands:\n";
    echo "  auto          - Perform automatic cleanup based on thresholds\n";
    echo "  force         - Force cleanup of old images regardless of thresholds\n";
    echo "  check-quota   - Check current quota usage and display recommendations\n";
    echo "  stats         - Display current usage statistics\n";
    echo "  report        - Generate and display usage report\n\n";
    echo "Options:\n";
    echo "  --dry-run     - Show what would be cleaned up without actually deleting\n";
    echo "  --verbose     - Display detailed progress information\n";
    echo "  --help        - Display this help message\n\n";
    echo "Examples:\n";
    echo "  php cloudinary_cleanup.php auto --verbose\n";
    echo "  php cloudinary_cleanup.php force --dry-run\n";
    echo "  php cloudinary_cleanup.php check-quota\n";
}

function main(): int {
    global $container;
    
    $args = $_SERVER['argv'] ?? [];
    $command = $args[1] ?? '';
    $options = array_slice($args, 2);
    
    $dryRun = in_array('--dry-run', $options);
    $verbose = in_array('--verbose', $options);
    $help = in_array('--help', $options);
    
    if ($help || empty($command)) {
        displayUsage();
        return 0;
    }
    
    try {
        $cloudinaryService = $container->get(\KiloShare\Services\CloudinaryService::class);
        $logger = $container->get(Psr\Log\LoggerInterface::class);
        
        $logger->info("Starting Cloudinary cleanup", [
            'command' => $command,
            'dry_run' => $dryRun,
            'verbose' => $verbose
        ]);
        
        if ($verbose) {
            echo "[" . date('Y-m-d H:i:s') . "] Starting Cloudinary cleanup: $command\n";
        }
        
        switch ($command) {
            case 'auto':
                $result = executeAutoCleanup($cloudinaryService, $dryRun, $verbose);
                break;
                
            case 'force':
                $result = executeForceCleanup($cloudinaryService, $dryRun, $verbose);
                break;
                
            case 'check-quota':
                $result = checkQuotaStatus($cloudinaryService, $verbose);
                break;
                
            case 'stats':
                $result = displayStats($cloudinaryService, $verbose);
                break;
                
            case 'report':
                $result = generateReport($cloudinaryService, $verbose);
                break;
                
            default:
                echo "Erreur: Commande inconnue '$command'\n";
                displayUsage();
                return 1;
        }
        
        if ($verbose) {
            echo "[" . date('Y-m-d H:i:s') . "] Cleanup completed successfully\n";
        }
        
        $logger->info("Cloudinary cleanup completed", [
            'command' => $command,
            'result' => $result
        ]);
        
        return 0;
        
    } catch (Exception $e) {
        $logger->error("Cloudinary cleanup failed", [
            'command' => $command,
            'error' => $e->getMessage(),
            'trace' => $e->getTraceAsString()
        ]);
        
        echo "Erreur: " . $e->getMessage() . "\n";
        if ($verbose) {
            echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
        }
        
        return 1;
    }
}

function executeAutoCleanup(CloudinaryService $service, bool $dryRun, bool $verbose): array {
    echo "Executing automatic cleanup...\n";
    
    // Vérifier d'abord les quotas
    $quotaStatus = $service->checkQuotaStatus();
    
    if ($verbose) {
        echo "Current quota usage:\n";
        echo "- Storage: {$quotaStatus['storage_percentage']}%\n";
        echo "- Bandwidth: {$quotaStatus['bandwidth_percentage']}%\n";
    }
    
    // Effectuer le nettoyage seulement si nécessaire
    if ($quotaStatus['storage_percentage'] > 75 || $quotaStatus['bandwidth_percentage'] > 75) {
        if ($verbose) {
            echo "Quota threshold exceeded, performing cleanup...\n";
        }
        
        $result = $service->performCleanup('auto', false, $dryRun);
        
        if ($verbose) {
            echo "Cleanup results:\n";
            echo "- Images cleaned: {$result['images_cleaned']}\n";
            echo "- Storage freed: {$result['storage_freed_mb']} MB\n";
            echo "- Bandwidth saved: {$result['bandwidth_saved_mb']} MB\n";
        }
        
        return $result;
    } else {
        if ($verbose) {
            echo "Quota usage is within acceptable limits, no cleanup needed.\n";
        }
        
        return [
            'images_cleaned' => 0,
            'storage_freed_mb' => 0,
            'bandwidth_saved_mb' => 0,
            'message' => 'No cleanup needed'
        ];
    }
}

function executeForceCleanup(CloudinaryService $service, bool $dryRun, bool $verbose): array {
    echo "Executing forced cleanup...\n";
    
    if (!$dryRun) {
        echo "WARNING: This will permanently delete old images. Continue? (y/N): ";
        $confirmation = trim(fgets(STDIN));
        
        if (strtolower($confirmation) !== 'y') {
            echo "Cleanup cancelled.\n";
            return ['message' => 'Cleanup cancelled by user'];
        }
    }
    
    $result = $service->performCleanup('force', true, $dryRun);
    
    if ($verbose) {
        echo "Force cleanup results:\n";
        echo "- Images cleaned: {$result['images_cleaned']}\n";
        echo "- Storage freed: {$result['storage_freed_mb']} MB\n";
        echo "- Bandwidth saved: {$result['bandwidth_saved_mb']} MB\n";
    }
    
    return $result;
}

function checkQuotaStatus(CloudinaryService $service, bool $verbose): array {
    echo "Checking quota status...\n";
    
    $quotaStatus = $service->checkQuotaStatus();
    
    echo "\n=== CLOUDINARY QUOTA STATUS ===\n";
    echo "Storage: {$quotaStatus['storage_percentage']}% used ({$quotaStatus['storage_used_mb']} MB / {$quotaStatus['storage_limit_mb']} MB)\n";
    echo "Bandwidth: {$quotaStatus['bandwidth_percentage']}% used ({$quotaStatus['bandwidth_used_mb']} MB / {$quotaStatus['bandwidth_limit_mb']} MB)\n";
    
    // Recommandations
    echo "\n=== RECOMMENDATIONS ===\n";
    
    if ($quotaStatus['storage_percentage'] > 90) {
        echo "⚠️  CRITICAL: Storage usage is very high! Immediate cleanup recommended.\n";
    } elseif ($quotaStatus['storage_percentage'] > 75) {
        echo "⚠️  WARNING: Storage usage is high. Consider running cleanup soon.\n";
    } else {
        echo "✅ Storage usage is acceptable.\n";
    }
    
    if ($quotaStatus['bandwidth_percentage'] > 90) {
        echo "⚠️  CRITICAL: Bandwidth usage is very high! Optimize image transformations.\n";
    } elseif ($quotaStatus['bandwidth_percentage'] > 75) {
        echo "⚠️  WARNING: Bandwidth usage is high. Monitor image requests.\n";
    } else {
        echo "✅ Bandwidth usage is acceptable.\n";
    }
    
    echo "\n";
    
    return $quotaStatus;
}

function displayStats(CloudinaryService $service, bool $verbose): array {
    echo "Fetching usage statistics...\n";
    
    $stats = $service->getUsageStats('monthly', true);
    
    echo "\n=== CLOUDINARY USAGE STATISTICS ===\n";
    echo "Total images: {$stats['total_images']}\n";
    echo "Monthly uploads: {$stats['monthly_uploads']}\n";
    echo "Average image size: {$stats['average_size_mb']} MB\n";
    echo "Compression ratio: {$stats['compression_ratio']}%\n";
    
    if ($verbose && isset($stats['by_type'])) {
        echo "\n=== BY IMAGE TYPE ===\n";
        foreach ($stats['by_type'] as $type => $typeStats) {
            echo "- $type: {$typeStats['count']} images, {$typeStats['total_size_mb']} MB total\n";
        }
    }
    
    return $stats;
}

function generateReport(CloudinaryService $service, bool $verbose): array {
    echo "Generating usage report...\n";
    
    $report = $service->generateUsageReport('last_month');
    
    echo "\n=== MONTHLY USAGE REPORT ===\n";
    echo "Report Period: {$report['period_start']} to {$report['period_end']}\n";
    echo "Total Uploads: {$report['total_uploads']}\n";
    echo "Total Storage Used: {$report['total_storage_mb']} MB\n";
    echo "Total Bandwidth Used: {$report['total_bandwidth_mb']} MB\n";
    echo "Average Compression: {$report['average_compression']}%\n";
    
    if ($verbose && isset($report['daily_breakdown'])) {
        echo "\n=== DAILY BREAKDOWN ===\n";
        foreach ($report['daily_breakdown'] as $day => $dayStats) {
            echo "- $day: {$dayStats['uploads']} uploads, {$dayStats['storage_mb']} MB storage\n";
        }
    }
    
    echo "\n";
    
    return $report;
}

// Exécuter le script principal seulement si appelé directement
if (realpath($_SERVER['argv'][0] ?? '') === realpath(__FILE__)) {
    exit(main());
}