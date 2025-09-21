<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "=== TRIP STATUS CHECK ===\n\n";

$trip = Trip::find(1);
if ($trip) {
    echo "Trip ID: {$trip->id}\n";
    echo "User ID: {$trip->user_id}\n";
    echo "Title: {$trip->title}\n";
    echo "Status: {$trip->status}\n";
    echo "Available actions: " . implode(', ', $trip->getAvailableActions()) . "\n\n";
    
    // Reset to draft status for testing
    echo "🔄 Resetting trip to draft status...\n";
    $trip->status = 'draft';
    $trip->save();
    
    echo "✅ Trip status updated to: {$trip->status}\n";
    echo "Available actions: " . implode(', ', $trip->getAvailableActions()) . "\n";
} else {
    echo "❌ Trip with ID 1 not found\n";
}