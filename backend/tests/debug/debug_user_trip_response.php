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

echo "=== DEBUG USER TRIP RESPONSE ===\n\n";

// Get user 5
$user = User::find(5);
$tokens = JWTHelper::generateTokens($user);
$token = $tokens['access_token'];

// Make API call to /user/trips/1
function makeApiCall($endpoint, $method = 'GET', $token = null) {
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
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return ['code' => $httpCode, 'response' => json_decode($response, true)];
}

$result = makeApiCall('/user/trips/1', 'GET', $token);
echo "Status: {$result['code']}\n";
echo "Full Response:\n";
echo json_encode($result['response'], JSON_PRETTY_PRINT) . "\n\n";

if (isset($result['response']['data']['trip'])) {
    $trip = $result['response']['data']['trip'];
    echo "=== TRIP DATA ANALYSIS ===\n";
    echo "Trip ID: " . ($trip['id'] ?? 'NOT SET') . "\n";
    echo "User ID field: " . ($trip['user_id'] ?? 'NOT SET') . "\n";
    echo "UserID field: " . ($trip['userId'] ?? 'NOT SET') . "\n";
    echo "Transport Type: " . ($trip['transport_type'] ?? 'NOT SET') . "\n";
    echo "Is Owner: " . ($trip['is_owner'] ? 'true' : 'false') . "\n";
    echo "Can Book: " . ($trip['can_book'] ? 'true' : 'false') . "\n";
    
    echo "\n=== ALL TRIP FIELDS ===\n";
    foreach ($trip as $key => $value) {
        echo "$key: " . (is_array($value) ? json_encode($value) : ($value ?? 'NULL')) . "\n";
    }
}