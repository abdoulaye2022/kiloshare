<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;
use KiloShare\Models\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "Testing trip access logic..." . PHP_EOL . PHP_EOL;

// Test data
$tripId = 1;
$userId = 5;

// Get trip
$trip = Trip::find($tripId);
if (!$trip) {
    echo "❌ Trip $tripId not found" . PHP_EOL;
    exit(1);
}

// Get user
$user = User::find($userId);
if (!$user) {
    echo "❌ User $userId not found" . PHP_EOL;
    exit(1);
}

echo "=== TRIP INFO ===" . PHP_EOL;
echo "Trip ID: {$trip->id}" . PHP_EOL;
echo "Trip Status: {$trip->status}" . PHP_EOL;
echo "Trip User ID: {$trip->user_id}" . PHP_EOL;
echo "STATUS_PUBLISHED constant: " . Trip::STATUS_PUBLISHED . PHP_EOL;

echo PHP_EOL . "=== USER INFO ===" . PHP_EOL;
echo "User ID: {$user->id}" . PHP_EOL;
echo "User Email: {$user->email}" . PHP_EOL;
echo "User Status: {$user->status}" . PHP_EOL;

echo PHP_EOL . "=== ACCESS LOGIC TEST ===" . PHP_EOL;

// Test the access logic from TripController
$isPublished = $trip->status === Trip::STATUS_PUBLISHED;
$isOwner = $trip->user_id === $user->id;
$hasAccess = $isPublished || $isOwner;

echo "Is trip published? " . ($isPublished ? "✅ Yes" : "❌ No") . PHP_EOL;
echo "Is user owner? " . ($isOwner ? "✅ Yes" : "❌ No") . PHP_EOL;
echo "Should have access? " . ($hasAccess ? "✅ Yes" : "❌ No") . PHP_EOL;

echo PHP_EOL . "=== ACCESS LOGIC BREAKDOWN ===" . PHP_EOL;
echo "trip->status = '{$trip->status}'" . PHP_EOL;
echo "Trip::STATUS_PUBLISHED = '" . Trip::STATUS_PUBLISHED . "'" . PHP_EOL;
echo "trip->status !== Trip::STATUS_PUBLISHED = " . ($trip->status !== Trip::STATUS_PUBLISHED ? "true" : "false") . PHP_EOL;
echo "trip->user_id = {$trip->user_id}" . PHP_EOL;
echo "user->id = {$user->id}" . PHP_EOL;
echo "trip->user_id !== user->id = " . ($trip->user_id !== $user->id ? "true" : "false") . PHP_EOL;

// The condition from TripController.php:
// if ($trip->status !== Trip::STATUS_PUBLISHED && (!$user || $trip->user_id !== $user->id))
$condition1 = $trip->status !== Trip::STATUS_PUBLISHED;
$condition2 = !$user || $trip->user_id !== $user->id;
$shouldForbid = $condition1 && $condition2;

echo PHP_EOL . "Final condition: (status !== published) AND (no user OR not owner)" . PHP_EOL;
echo "  Condition 1 (not published): " . ($condition1 ? "true" : "false") . PHP_EOL;  
echo "  Condition 2 (no user or not owner): " . ($condition2 ? "true" : "false") . PHP_EOL;
echo "  Should forbid access: " . ($shouldForbid ? "❌ YES (FORBIDDEN)" : "✅ NO (ALLOWED)") . PHP_EOL;

// Generate a fresh token for this test
echo PHP_EOL . "=== JWT TOKEN TEST ===" . PHP_EOL;
$settings = require __DIR__ . '/config/settings.php';
$jwtConfig = $settings['jwt'];

$now = time();
$accessTokenExpiry = $now + $jwtConfig['access_token_expiry'];

$accessPayload = [
    'iss' => $jwtConfig['issuer'],
    'aud' => $jwtConfig['audience'],
    'iat' => $now,
    'exp' => $accessTokenExpiry,
    'sub' => $user->uuid,
    'user' => [
        'id' => $user->id,
        'uuid' => $user->uuid,
        'email' => $user->email,
        'phone' => $user->phone,
        'first_name' => $user->first_name,
        'last_name' => $user->last_name,
        'is_verified' => $user->is_verified,
        'role' => $user->role,
    ],
    'type' => 'access'
];

$token = JWT::encode($accessPayload, $jwtConfig['secret'], $jwtConfig['algorithm']);
echo "Fresh JWT Token: " . substr($token, 0, 50) . "..." . PHP_EOL;

// Test token validation
try {
    $decoded = JWT::decode($token, new Key($jwtConfig['secret'], $jwtConfig['algorithm']));
    echo "Token validation: ✅ SUCCESS" . PHP_EOL;
    echo "Token user ID: {$decoded->user->id}" . PHP_EOL;
    echo "Token user email: {$decoded->user->email}" . PHP_EOL;
} catch (Exception $e) {
    echo "Token validation: ❌ FAILED - " . $e->getMessage() . PHP_EOL;
}

echo PHP_EOL . "Full fresh token for testing:" . PHP_EOL;
echo $token . PHP_EOL;