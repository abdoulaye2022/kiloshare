<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Utils\JWTHelper;
use KiloShare\Models\User;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "Testing Authentication..." . PHP_EOL;

// Find user 5
$user = User::find(5);
if (!$user) {
    echo "User 5 not found!" . PHP_EOL;
    exit(1);
}

echo "User 5 found:" . PHP_EOL;
echo "  ID: " . $user->id . PHP_EOL;
echo "  Email: " . $user->email . PHP_EOL;
echo "  Status: " . $user->status . PHP_EOL;
echo "  Role: " . $user->role . PHP_EOL;
echo "  Is Active: " . ($user->isActive() ? 'Yes' : 'No') . PHP_EOL;

// Generate tokens using JWTHelper
echo PHP_EOL . "Generating JWT tokens..." . PHP_EOL;
$tokens = JWTHelper::generateTokens($user);
echo "Access Token: " . substr($tokens['access_token'], 0, 50) . "..." . PHP_EOL;
echo "Refresh Token: " . substr($tokens['refresh_token'], 0, 50) . "..." . PHP_EOL;

// Test token validation
echo PHP_EOL . "Testing token validation..." . PHP_EOL;
$payload = JWTHelper::validateToken($tokens['access_token']);
if ($payload) {
    echo "Token validation successful!" . PHP_EOL;
    echo "  User ID: " . $payload['user_id'] . PHP_EOL;
    echo "  Email: " . $payload['email'] . PHP_EOL;
    echo "  Role: " . $payload['role'] . PHP_EOL;
} else {
    echo "Token validation failed!" . PHP_EOL;
}

// Test user retrieval from token
echo PHP_EOL . "Testing user retrieval from token..." . PHP_EOL;
$userFromToken = JWTHelper::getUserFromToken($tokens['access_token']);
if ($userFromToken) {
    echo "User retrieval from token successful!" . PHP_EOL;
    echo "  ID: " . $userFromToken->id . PHP_EOL;
    echo "  Email: " . $userFromToken->email . PHP_EOL;
} else {
    echo "User retrieval from token failed!" . PHP_EOL;
}

echo PHP_EOL . "Full access token for testing:" . PHP_EOL;
echo $tokens['access_token'] . PHP_EOL;