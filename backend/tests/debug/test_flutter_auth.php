<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;
use KiloShare\Models\User;
use KiloShare\Utils\JWTHelper;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "=== FLUTTER AUTH TEST ===\n\n";

// Get user 5
$user = User::find(5);
if (!$user) {
    echo "❌ User 5 not found\n";
    exit(1);
}

echo "👤 User found:\n";
echo "   ID: {$user->id}\n";
echo "   Name: {$user->first_name} {$user->last_name}\n";
echo "   Email: {$user->email}\n";
echo "   Status: {$user->status}\n\n";

// Generate JWT token
$tokens = JWTHelper::generateTokens($user);
$token = $tokens['access_token'];

echo "🔑 JWT Token generated:\n";
echo "   Token (first 50 chars): " . substr($token, 0, 50) . "...\n\n";

// Test API endpoints that Flutter calls
function makeApiCall($endpoint, $method = 'GET', $token = null, $data = null) {
    $url = "http://localhost:8080/api/v1" . $endpoint;
    $headers = ['Content-Type: application/json'];
    
    if ($token) {
        $headers[] = "Authorization: Bearer $token";
    }
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return ['code' => $httpCode, 'response' => json_decode($response, true)];
}

// Test 1: Check /auth/me endpoint (what Flutter uses to get current user)
echo "🧪 Test 1: GET /auth/me\n";
$result = makeApiCall('/auth/me', 'GET', $token);
echo "   Status: {$result['code']}\n";
if ($result['response']) {
    if (isset($result['response']['user']['id'])) {
        echo "   User ID returned: {$result['response']['user']['id']}\n";
        echo "   User ID type: " . gettype($result['response']['user']['id']) . "\n";
    } else {
        echo "   ❌ No user ID in response\n";
        echo "   Response: " . json_encode($result['response'], JSON_PRETTY_PRINT) . "\n";
    }
} else {
    echo "   ❌ No response data\n";
}
echo "\n";

// Test 2: Check /user/trips/1 endpoint (what Flutter uses to get user's specific trip)
echo "🧪 Test 2: GET /user/trips/1\n";
$result = makeApiCall('/user/trips/1', 'GET', $token);
echo "   Status: {$result['code']}\n";
if ($result['response']) {
    if (isset($result['response']['data']['trip'])) {
        $trip = $result['response']['data']['trip'];
        echo "   Trip ID: {$trip['id']}\n";
        $tripUserId = isset($trip['userId']) ? $trip['userId'] : (isset($trip['user_id']) ? $trip['user_id'] : 'NOT FOUND');
        echo "   Trip User ID: {$tripUserId}\n";
        echo "   Trip Status: {$trip['status']}\n";
        echo "   Is Owner field: " . (isset($trip['is_owner']) ? ($trip['is_owner'] ? 'true' : 'false') : 'NOT SET') . "\n";
    } else {
        echo "   ❌ No trip data in response\n";
        echo "   Response: " . json_encode($result['response'], JSON_PRETTY_PRINT) . "\n";
    }
} else {
    echo "   ❌ No response data\n";
}
echo "\n";

// Test 3: Check /trips/1 endpoint (public trip endpoint)
echo "🧪 Test 3: GET /trips/1 (with auth)\n";
$result = makeApiCall('/trips/1', 'GET', $token);
echo "   Status: {$result['code']}\n";
if ($result['response']) {
    if (isset($result['response']['data']['trip'])) {
        $trip = $result['response']['data']['trip'];
        echo "   Trip ID: {$trip['id']}\n";
        $tripUserId2 = isset($trip['user']['id']) ? $trip['user']['id'] : 'NOT FOUND';
        echo "   Trip User ID: {$tripUserId2}\n";
        echo "   Trip Status: {$trip['status']}\n";
        echo "   Is Owner field: " . (isset($trip['is_owner']) ? ($trip['is_owner'] ? 'true' : 'false') : 'NOT SET') . "\n";
        echo "   Can Book field: " . (isset($trip['can_book']) ? ($trip['can_book'] ? 'true' : 'false') : 'NOT SET') . "\n";
    } else {
        echo "   ❌ No trip data in response\n";
        echo "   Response: " . json_encode($result['response'], JSON_PRETTY_PRINT) . "\n";
    }
} else {
    echo "   ❌ No response data\n";
}
echo "\n";

echo "=== SUMMARY ===\n";
echo "If Flutter shows visitor buttons instead of owner buttons:\n";
echo "1. Check that JWT token is being stored and sent correctly\n";
echo "2. Check that user ID comparison is working (string vs int)\n";
echo "3. Check that _isOwner flag is being set correctly\n";
echo "4. Check console logs in Flutter for authentication errors\n";