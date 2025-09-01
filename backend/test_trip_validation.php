<?php
// Test simple de validation d'un voyage via l'API

$baseUrl = 'http://127.0.0.1:8080/api/v1';

// Données d'un voyage Montreal -> Londres (international, devrait fonctionner)
$tripData = [
    'departure_city' => 'Montreal',
    'departure_country' => 'Canada',
    'departure_airport_code' => 'YUL',
    'departure_date' => '2025-12-25 10:00:00',
    'arrival_city' => 'London',
    'arrival_country' => 'UK',
    'arrival_airport_code' => 'LHR',
    'arrival_date' => '2025-12-25 20:00:00',
    'transport_type' => 'flight',
    'flight_number' => 'AC856',
    'airline' => 'Air Canada',
    'available_weight_kg' => 15.0,
    'price_per_kg' => 25.0,
    'currency' => 'CAD',
    'description' => 'Test voyage international Canada -> UK'
];

// Test avec curl
$ch = curl_init($baseUrl . '/trips');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer dummy_token_for_test'
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($tripData));

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "=== Test Validation Voyage ===\n";
echo "Code HTTP: $httpCode\n";
echo "Réponse: $response\n";

// Essayons aussi de tester directement l'endpoint de publication d'un voyage existant
echo "\n=== Test Publication Voyage ID 19 ===\n";

$ch = curl_init($baseUrl . '/trips/19/publish');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer dummy_token_for_test'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Code HTTP: $httpCode\n";
echo "Réponse: $response\n";