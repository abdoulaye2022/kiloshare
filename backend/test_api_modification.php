<?php

// Simple API test without internal dependencies
$baseUrl = 'http://localhost:8000/api/v1';

// Function to make API calls
function makeApiCall($url, $method = 'GET', $data = null, $token = null) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    
    $headers = ['Content-Type: application/json'];
    if ($token) {
        $headers[] = 'Authorization: Bearer ' . $token;
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    
    if ($data) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'code' => $httpCode,
        'response' => json_decode($response, true) ?: $response
    ];
}

echo "=== Testing Trip Modification API ===\n\n";

// Step 1: Test authentication (get an existing user's token)
echo "1. Testing authentication...\n";
$loginData = [
    'email' => 'test@example.com', // Use a test user
    'password' => 'password123'
];

$authResult = makeApiCall($baseUrl . '/auth/login', 'POST', $loginData);
echo "Auth response code: " . $authResult['code'] . "\n";

if ($authResult['code'] !== 200) {
    echo "Authentication failed. Let's try creating a test user first.\n";
    
    $registerData = [
        'first_name' => 'Test',
        'last_name' => 'User',
        'email' => 'testmod' . time() . '@example.com',
        'password' => 'password123',
        'phone' => '+1234567890'
    ];
    
    $registerResult = makeApiCall($baseUrl . '/auth/register', 'POST', $registerData);
    echo "Register response code: " . $registerResult['code'] . "\n";
    
    if ($registerResult['code'] === 201) {
        echo "✓ Test user created\n";
        $token = $registerResult['response']['data']['token'] ?? null;
    } else {
        echo "❌ Failed to create test user\n";
        print_r($registerResult['response']);
        exit(1);
    }
} else {
    echo "✓ Authentication successful\n";
    $token = $authResult['response']['data']['token'] ?? null;
}

if (!$token) {
    echo "❌ No token received\n";
    exit(1);
}

echo "Token: " . substr($token, 0, 20) . "...\n\n";

// Step 2: Create a test trip
echo "2. Creating test trip with restrictions...\n";
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
    'description' => 'Test trip for restriction modification',
    'restricted_categories' => ['electronics', 'fragile'],
    'restricted_items' => ['laptop', 'phone'],
    'restriction_notes' => 'Handle with care - original'
];

$createResult = makeApiCall($baseUrl . '/trips', 'POST', $createData, $token);
echo "Create response code: " . $createResult['code'] . "\n";

if ($createResult['code'] !== 201) {
    echo "❌ Failed to create trip\n";
    print_r($createResult['response']);
    exit(1);
}

$tripId = $createResult['response']['data']['id'] ?? null;
if (!$tripId) {
    echo "❌ No trip ID received\n";
    exit(1);
}

echo "✓ Trip created with ID: $tripId\n\n";

// Step 3: Modify the trip with new restrictions 
echo "3. Modifying trip with updated restrictions...\n";
$updateData = [
    'available_weight_kg' => 15.0,
    'price_per_kg' => 30.0,
    'description' => 'Updated trip with new restrictions',
    'restricted_categories' => ['electronics', 'liquids', 'batteries'],
    'restricted_items' => ['laptop', 'perfume', 'power bank'],
    'restriction_notes' => 'Updated restrictions - no batteries allowed',
    'allow_partial_booking' => true,
    'instant_booking' => false,
    'min_user_rating' => 4.0,
    'min_user_trips' => 2,
    'visibility' => 'public'
];

$updateResult = makeApiCall($baseUrl . '/trips/' . $tripId, 'PUT', $updateData, $token);
echo "Update response code: " . $updateResult['code'] . "\n";

if ($updateResult['code'] !== 200) {
    echo "❌ Failed to update trip\n";
    print_r($updateResult['response']);
} else {
    echo "✓ Trip updated successfully\n";
}

echo "\n";

// Step 4: Retrieve the updated trip and check all fields
echo "4. Retrieving updated trip to verify fields...\n";
$getResult = makeApiCall($baseUrl . '/trips/' . $tripId, 'GET', null, $token);
echo "Get response code: " . $getResult['code'] . "\n";

if ($getResult['code'] !== 200) {
    echo "❌ Failed to retrieve trip\n";
    print_r($getResult['response']);
} else {
    echo "✓ Trip retrieved successfully\n\n";
    
    $trip = $getResult['response']['data'] ?? [];
    
    // Check the problematic fields
    $problematicFields = [
        'cancellation_reason', 'cancellation_details', 'pause_reason',
        'is_approved', 'auto_approved', 'moderated_by', 'moderation_notes',
        'trust_score_at_creation', 'requires_manual_review', 'review_priority',
        'share_count', 'favorite_count', 'report_count', 'duplicate_count',
        'edit_count', 'total_booked_weight', 'remaining_weight',
        'is_urgent', 'is_featured', 'is_verified', 'auto_expire',
        'allow_partial_booking', 'instant_booking', 'visibility',
        'min_user_rating', 'min_user_trips', 'blocked_users',
        'slug', 'meta_title', 'meta_description'
    ];
    
    echo "=== Checking Problematic Fields ===\n";
    $nullCount = 0;
    $validCount = 0;
    
    foreach ($problematicFields as $field) {
        $value = $trip[$field] ?? 'MISSING';
        
        if ($value === null) {
            echo "⚠️  $field: NULL\n";
            $nullCount++;
        } elseif ($value === 'MISSING') {
            echo "❌ $field: MISSING\n"; 
            $nullCount++;
        } else {
            echo "✅ $field: ";
            if (is_array($value) || is_object($value)) {
                echo json_encode($value);
            } else {
                echo $value;
            }
            echo "\n";
            $validCount++;
        }
    }
    
    echo "\n=== Restriction Fields ===\n";
    echo "✅ restricted_categories: " . json_encode($trip['restricted_categories'] ?? null) . "\n";
    echo "✅ restricted_items: " . json_encode($trip['restricted_items'] ?? null) . "\n";
    echo "✅ restriction_notes: " . ($trip['restriction_notes'] ?? 'NULL') . "\n";
    
    echo "\n=== Summary ===\n";
    echo "Valid fields: $validCount\n";
    echo "Null/Missing fields: $nullCount\n";
    
    if ($nullCount > 0) {
        echo "⚠️  Some fields are null/missing, but this might be expected for optional fields.\n";
    } else {
        echo "✅ All fields are properly set!\n";
    }
}

// Step 5: Clean up
echo "\n5. Cleaning up test trip...\n";
$deleteResult = makeApiCall($baseUrl . '/trips/' . $tripId, 'DELETE', null, $token);
echo "Delete response code: " . $deleteResult['code'] . "\n";
echo "✓ Test completed\n";