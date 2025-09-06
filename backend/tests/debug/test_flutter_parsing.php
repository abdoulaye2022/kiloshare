<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "Testing Flutter model parsing with API response..." . PHP_EOL . PHP_EOL;

$tripId = 1;
$trip = Trip::with(['user', 'images', 'bookings'])->find($tripId);

if (!$trip) {
    echo "❌ Trip $tripId not found" . PHP_EOL;
    exit(1);
}

// Simulate the API response structure like in TripController.php
$apiResponse = [
    'id' => $trip->id,
    'uuid' => $trip->uuid,
    'title' => $trip->title,
    'description' => $trip->description,
    'departure_city' => $trip->departure_city,
    'departure_country' => $trip->departure_country,
    'departure_date' => $trip->departure_date,
    'arrival_city' => $trip->arrival_city,
    'arrival_country' => $trip->arrival_country,
    'arrival_date' => $trip->arrival_date,
    'transport_type' => $trip->transport_type,
    'max_weight' => $trip->available_weight_kg,  // Original capacity
    'available_weight' => $trip->available_weight,  // Calculated available
    'price_per_kg' => $trip->price_per_kg,
    'total_reward' => $trip->total_reward,
    'currency' => $trip->currency,
    'status' => $trip->status,
];

echo "=== API RESPONSE SIMULATION ===" . PHP_EOL;
echo "max_weight: {$apiResponse['max_weight']}" . PHP_EOL;
echo "available_weight: {$apiResponse['available_weight']}" . PHP_EOL;
echo "available_weight_kg: " . (isset($apiResponse['available_weight_kg']) ? $apiResponse['available_weight_kg'] : 'NOT SET') . PHP_EOL;

echo PHP_EOL . "=== FLUTTER PARSING LOGIC ===" . PHP_EOL;
echo "Priority 1 - available_weight: " . ($apiResponse['available_weight'] ?? 'null') . PHP_EOL;
echo "Priority 2 - available_weight_kg: " . (isset($apiResponse['available_weight_kg']) ? $apiResponse['available_weight_kg'] : 'null') . PHP_EOL; 
echo "Priority 3 - max_weight: " . ($apiResponse['max_weight'] ?? 'null') . PHP_EOL;

// Simulate Flutter parsing logic
$parseDouble = function($value) {
    if ($value === null) return null;
    return (float)$value;
};

$flutterAvailableWeightKg = $parseDouble($apiResponse['available_weight'] ?? null) ?? 
                           $parseDouble($apiResponse['available_weight_kg'] ?? null) ?? 
                           $parseDouble($apiResponse['max_weight'] ?? null);

echo PHP_EOL . "Final Flutter availableWeightKg: {$flutterAvailableWeightKg}" . PHP_EOL;

echo PHP_EOL . "=== VERIFICATION ===" . PHP_EOL;
if ($flutterAvailableWeightKg == 15.0) {
    echo "✅ SUCCESS: Flutter would parse availableWeightKg as 15.0 kg" . PHP_EOL;
} else {
    echo "❌ FAILURE: Flutter would parse availableWeightKg as {$flutterAvailableWeightKg} instead of 15.0" . PHP_EOL;
}

echo PHP_EOL . "=== JSON RESPONSE FOR REFERENCE ===" . PHP_EOL;
echo json_encode($apiResponse, JSON_PRETTY_PRINT) . PHP_EOL;