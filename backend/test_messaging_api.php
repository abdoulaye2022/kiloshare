<?php

require 'vendor/autoload.php';

use KiloShare\Models\User;

$config = require 'config/database.php';
$capsule = new Illuminate\Database\Capsule\Manager;
$capsule->addConnection($config['connections']['mysql']);
$capsule->setAsGlobal();
$capsule->bootEloquent();

// Get the admin user
$user = User::where('email', 'admin@gmail.com')->first();
if (!$user) {
    echo "❌ Admin user not found\n";
    exit(1);
}

echo "✅ Admin user found: {$user->first_name} {$user->last_name} (ID: {$user->id})\n";

// Generate a token for testing
$token = \KiloShare\Utils\JWTHelper::generateAccessToken($user);

echo "✅ Token generated: " . substr($token, 0, 50) . "...\n";

// Test the API
$baseUrl = 'http://127.0.0.1:8080/api/v1';

// Test 1: Create or get conversation (use admin user as requester and trip_owner_id=1 as owner - same user but API should handle it)
echo "\n=== Testing Conversation Creation ===\n";
$conversationData = [
    'trip_id' => '1',
    'trip_owner_id' => '1' // Try same user to see error, then we'll create a different user
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $baseUrl . '/conversations');
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($conversationData));
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $token
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
echo "Response: " . json_encode(json_decode($response, true), JSON_PRETTY_PRINT) . "\n";

$conversationResponse = json_decode($response, true);
if ($conversationResponse['success'] == true && isset($conversationResponse['data']['conversation']['id'])) {
    $conversationId = $conversationResponse['data']['conversation']['id'];
    
    // Test 2: Send message
    echo "\n=== Testing Message Sending ===\n";
    $messageData = [
        'content' => 'Bonjour, je suis intéressé par votre voyage!'
    ];
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $baseUrl . '/conversations/' . $conversationId . '/messages');
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($messageData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $token
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "HTTP Code: $httpCode\n";
    echo "Response: " . json_encode(json_decode($response, true), JSON_PRETTY_PRINT) . "\n";
    
    // Test 3: Get messages
    echo "\n=== Testing Message Retrieval ===\n";
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $baseUrl . '/conversations/' . $conversationId . '/messages');
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $token
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "HTTP Code: $httpCode\n";
    echo "Response: " . json_encode(json_decode($response, true), JSON_PRETTY_PRINT) . "\n";
}
?>