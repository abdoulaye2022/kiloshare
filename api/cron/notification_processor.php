<?php

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/database.php';

use KiloShare\Services\NotificationService;
use KiloShare\Models\NotificationQueue;
use KiloShare\Models\Notification;

$notificationService = new NotificationService();
$queue = new NotificationQueue();
$notification = new Notification();

echo "[" . date('Y-m-d H:i:s') . "] Starting notification processor...\n";

try {
    // Process pending notifications in queue
    $pendingNotifications = $queue->getPending(50);
    $processedCount = 0;
    $failedCount = 0;

    foreach ($pendingNotifications as $queueItem) {
        try {
            $data = json_decode($queueItem['data'], true);
            
            echo "[" . date('Y-m-d H:i:s') . "] Processing notification {$queueItem['id']} for user {$queueItem['user_id']}\n";
            
            $result = $notificationService->send(
                $queueItem['user_id'],
                $queueItem['type'],
                $data['variables'] ?? [],
                $data['options'] ?? []
            );
            
            if ($result['success']) {
                $queue->markAsProcessed($queueItem['id']);
                $processedCount++;
                echo "[" . date('Y-m-d H:i:s') . "] ✓ Notification {$queueItem['id']} processed successfully\n";
            } else {
                $queue->markAsFailed($queueItem['id'], $result['error'] ?? 'Unknown error');
                $failedCount++;
                echo "[" . date('Y-m-d H:i:s') . "] ✗ Notification {$queueItem['id']} failed: " . ($result['error'] ?? 'Unknown error') . "\n";
            }
            
        } catch (Exception $e) {
            $queue->markAsFailed($queueItem['id'], $e->getMessage());
            $failedCount++;
            echo "[" . date('Y-m-d H:i:s') . "] ✗ Exception processing notification {$queueItem['id']}: " . $e->getMessage() . "\n";
        }
        
        // Small delay to avoid overwhelming external APIs
        usleep(100000); // 0.1 second
    }

    // Clean up old processed notifications (older than 7 days)
    $cleanedCount = $queue->cleanupProcessed(7);
    if ($cleanedCount > 0) {
        echo "[" . date('Y-m-d H:i:s') . "] Cleaned up {$cleanedCount} old processed notifications\n";
    }

    // Clean up old expired notifications (older than 30 days)
    $expiredCount = $notification->cleanupExpired();
    if ($expiredCount > 0) {
        echo "[" . date('Y-m-d H:i:s') . "] Cleaned up {$expiredCount} expired notifications\n";
    }

    echo "[" . date('Y-m-d H:i:s') . "] Notification processor completed. Processed: {$processedCount}, Failed: {$failedCount}\n";

} catch (Exception $e) {
    echo "[" . date('Y-m-d H:i:s') . "] Fatal error in notification processor: " . $e->getMessage() . "\n";
    exit(1);
}