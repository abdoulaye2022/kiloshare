<?php
require_once __DIR__ . '/vendor/autoload.php';

use src\Config\Database;
use src\Services\JWTService;

$database = new Database();
$pdo = $database->getConnection();
$jwtService = new JWTService();

// Test user (use your actual user ID)
$userId = 1;
$token = $jwtService->generateToken(['user_id' => $userId]);

// Base URL
$baseUrl = 'http://localhost:8000/api/v1/trips';

echo "=== Test Trip Modification with Restrictions ===\n\n";

// Step 1: Create a test trip
echo "1. Creating test trip...\n";
$createData = [
    'departure_city' => 'Toronto',
    'departure_country' => 'Canada',
    'departure_date' => '2025-12-25 10:00:00',
    'arrival_city' => 'Montreal',
    'arrival_country' => 'Canada',
    'arrival_date' => '2025-12-25 12:00:00',
    'transport_type' => 'car',
    'available_weight_kg' => 10.5,
    'price_per_kg' => 25.0,
    'currency' => 'CAD',
    'description' => 'Test trip for modification',
    'restricted_categories' => json_encode(['electronics', 'fragile']),
    'restricted_items' => json_encode(['laptop', 'phone']),
    'restriction_notes' => 'Handle with care'
];

$ch = curl_init($baseUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token,
    'Content-Type: application/json'
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($createData));

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 201) {
    echo "Failed to create trip. HTTP Code: $httpCode\n";
    echo "Response: $response\n";
    exit(1);
}

$createResult = json_decode($response, true);
$tripId = $createResult['data']['id'];
echo "✓ Trip created with ID: $tripId\n\n";

// Step 2: Modify the trip with various restriction settings
echo "2. Modifying trip with new restrictions...\n";
$updateData = [
    'available_weight_kg' => 15.0,
    'price_per_kg' => 30.0,
    'description' => 'Updated test trip with new restrictions',
    'restricted_categories' => json_encode(['electronics', 'liquids', 'batteries']),
    'restricted_items' => json_encode(['laptop', 'perfume', 'power bank']),
    'restriction_notes' => 'Updated restrictions - no batteries allowed',
    'allow_partial_booking' => true,
    'instant_booking' => false,
    'min_user_rating' => 4.0,
    'min_user_trips' => 2,
    'visibility' => 'public'
];

$ch = curl_init($baseUrl . '/' . $tripId);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token,
    'Content-Type: application/json'
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($updateData));

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
echo "Response: " . json_encode(json_decode($response), JSON_PRETTY_PRINT) . "\n\n";

if ($httpCode !== 200) {
    echo "Failed to update trip. HTTP Code: $httpCode\n";
    exit(1);
}

$updateResult = json_decode($response, true);
echo "✓ Trip updated successfully\n\n";

// Step 3: Retrieve the trip and verify all fields are properly set
echo "3. Retrieving updated trip to verify all fields...\n";
$ch = curl_init($baseUrl . '/' . $tripId);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    echo "Failed to retrieve trip. HTTP Code: $httpCode\n";
    exit(1);
}

$retrieveResult = json_decode($response, true);
$trip = $retrieveResult['data'];

// Check all the problematic fields mentioned in the bug report
$fieldsToCheck = [
    'cancellation_reason',
    'cancellation_details', 
    'pause_reason',
    'is_approved',
    'auto_approved',
    'moderated_by',
    'moderation_notes',
    'trust_score_at_creation',
    'requires_manual_review',
    'review_priority',
    'share_count',
    'favorite_count',
    'report_count',
    'duplicate_count',
    'edit_count',
    'total_booked_weight',
    'remaining_weight',
    'is_urgent',
    'is_featured',
    'is_verified',
    'auto_expire',
    'allow_partial_booking',
    'instant_booking',
    'visibility',
    'min_user_rating',
    'min_user_trips',
    'blocked_users',
    'slug',
    'meta_title',
    'meta_description',
    'restricted_categories',
    'restricted_items',
    'restriction_notes'
];

echo "=== Field Verification ===\n";
$nullFields = [];
$validFields = [];

foreach ($fieldsToCheck as $field) {
    $value = $trip[$field] ?? 'MISSING';
    
    if ($value === null) {
        $nullFields[] = $field;
        echo "⚠  $field: NULL\n";
    } elseif ($value === 'MISSING') {
        $nullFields[] = $field;
        echo "❌ $field: MISSING\n";
    } else {
        $validFields[] = $field;
        if (is_array($value) || is_object($value)) {
            echo "✓  $field: " . json_encode($value) . "\n";
        } else {
            echo "✓  $field: $value\n";
        }
    }
}

echo "\n=== Summary ===\n";
echo "✅ Valid fields: " . count($validFields) . "\n";
echo "⚠️  Null/Missing fields: " . count($nullFields) . "\n";

if (!empty($nullFields)) {
    echo "\nProblematic fields:\n";
    foreach ($nullFields as $field) {
        echo "  - $field\n";
    }
}

// Step 4: Test specific restriction functionality
echo "\n4. Testing restriction parsing...\n";
if (isset($trip['restricted_categories'])) {
    $categories = is_string($trip['restricted_categories']) 
        ? json_decode($trip['restricted_categories'], true) 
        : $trip['restricted_categories'];
    echo "✓ Restricted categories: " . json_encode($categories) . "\n";
}

if (isset($trip['restricted_items'])) {
    $items = is_string($trip['restricted_items']) 
        ? json_decode($trip['restricted_items'], true) 
        : $trip['restricted_items'];
    echo "✓ Restricted items: " . json_encode($items) . "\n";
}

echo "✓ Restriction notes: " . ($trip['restriction_notes'] ?? 'NULL') . "\n";

echo "\n=== Test Complete ===\n";

// Clean up - delete the test trip
echo "5. Cleaning up test trip...\n";
$ch = curl_init($baseUrl . '/' . $tripId);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "✓ Test trip deleted\n";
echo "Test completed successfully!\n";