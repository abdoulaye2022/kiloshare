<?php

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/database.php';

use KiloShare\Models\NotificationLog;

$logModel = new NotificationLog();

echo "[" . date('Y-m-d H:i:s') . "] Starting log cleanup...\n";

try {
    // Clean up notification logs older than 30 days
    $deletedLogs = $logModel->cleanupOldLogs(30);
    echo "[" . date('Y-m-d H:i:s') . "] Deleted {$deletedLogs} old notification logs\n";

    // Clean up failed logs older than 7 days (keep successful ones longer)
    $deletedFailedLogs = $logModel->cleanupFailedLogs(7);
    echo "[" . date('Y-m-d H:i:s') . "] Deleted {$deletedFailedLogs} old failed notification logs\n";

    // Rotate log files if they're too large (over 10MB)
    $logDir = __DIR__ . '/../logs';
    $logFiles = ['notification_processor.log', 'trip_reminders.log', 'cleanup.log'];

    foreach ($logFiles as $logFile) {
        $filePath = $logDir . '/' . $logFile;
        if (file_exists($filePath) && filesize($filePath) > 10 * 1024 * 1024) { // 10MB
            $rotatedPath = $filePath . '.' . date('Y-m-d');
            rename($filePath, $rotatedPath);
            echo "[" . date('Y-m-d H:i:s') . "] Rotated log file: {$logFile}\n";
            
            // Compress the rotated file
            if (function_exists('gzopen')) {
                $source = fopen($rotatedPath, 'rb');
                $dest = gzopen($rotatedPath . '.gz', 'wb9');
                
                while (!feof($source)) {
                    gzwrite($dest, fread($source, 8192));
                }
                
                fclose($source);
                gzclose($dest);
                unlink($rotatedPath);
                echo "[" . date('Y-m-d H:i:s') . "] Compressed rotated log: {$logFile}.gz\n";
            }
        }
    }

    // Delete compressed log files older than 30 days
    $compressedLogs = glob($logDir . '/*.gz');
    $deletedCompressed = 0;
    
    foreach ($compressedLogs as $compressedLog) {
        if (filemtime($compressedLog) < strtotime('-30 days')) {
            unlink($compressedLog);
            $deletedCompressed++;
        }
    }
    
    if ($deletedCompressed > 0) {
        echo "[" . date('Y-m-d H:i:s') . "] Deleted {$deletedCompressed} old compressed log files\n";
    }

    echo "[" . date('Y-m-d H:i:s') . "] Log cleanup completed successfully\n";

} catch (Exception $e) {
    echo "[" . date('Y-m-d H:i:s') . "] Fatal error in log cleanup: " . $e->getMessage() . "\n";
    exit(1);
}