<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\User;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "Creating test user for authentication..." . PHP_EOL;

// Check if user 5 exists
$user5 = User::find(5);
if ($user5) {
    echo "User 5 exists:" . PHP_EOL;
    echo "  Email: " . $user5->email . PHP_EOL;
    
    // Update user 5 with a known password for testing
    $hashedPassword = password_hash('testpassword123', PASSWORD_BCRYPT);
    $user5->password_hash = $hashedPassword;
    $user5->save();
    
    echo "  Updated password to: testpassword123" . PHP_EOL;
    echo "  Status: " . $user5->status . PHP_EOL;
} else {
    echo "User 5 not found!" . PHP_EOL;
}

// Also check all users for testing
echo PHP_EOL . "All users in database:" . PHP_EOL;
$users = User::all();
foreach ($users as $user) {
    echo "  ID: {$user->id}, Email: {$user->email}, Status: {$user->status}" . PHP_EOL;
}