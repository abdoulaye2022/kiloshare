<?php

// Test simple de l'API pour les vols domestiques
$baseUrl = 'http://localhost:8000/api/v1';

function testApiCall($url, $method = 'POST', $data = null) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    
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

echo "=== Test Vol Domestique Canadien via API ===\n\n";

// Test: Créer un vol domestique Toronto -> Vancouver
echo "Test création vol domestique Toronto -> Vancouver...\n";

$domesticFlightData = [
    'departure_city' => 'Toronto',
    'departure_country' => 'Canada', 
    'departure_airport_code' => 'YYZ',
    'departure_date' => '2025-12-25 10:00:00',
    'arrival_city' => 'Vancouver',
    'arrival_country' => 'Canada',
    'arrival_airport_code' => 'YVR',
    'arrival_date' => '2025-12-25 15:00:00',
    'transport_type' => 'flight',
    'flight_number' => 'AC123',
    'airline' => 'Air Canada',
    'available_weight_kg' => 15.0,
    'price_per_kg' => 30.0,
    'currency' => 'CAD',
    'description' => 'Test vol domestique canadien'
];

$result = testApiCall($baseUrl . '/trips', 'POST', $domesticFlightData);

echo "Code de réponse: " . $result['code'] . "\n";
echo "Réponse: " . json_encode($result['response'], JSON_PRETTY_PRINT) . "\n\n";

if ($result['code'] === 201) {
    echo "✅ SUCCESS: Vol domestique canadien AUTORISÉ!\n";
} else {
    echo "❌ ERREUR: Vol domestique canadien toujours bloqué\n";
    if (is_array($result['response']) && isset($result['response']['message'])) {
        echo "Message d'erreur: " . $result['response']['message'] . "\n";
    }
    if (is_array($result['response']) && isset($result['response']['errors'])) {
        echo "Détails des erreurs:\n";
        foreach ($result['response']['errors'] as $error) {
            echo "  - $error\n";
        }
    }
}

echo "\n=== Test Vol International (pour comparaison) ===\n";

// Test: Vol international Montreal -> Paris (devrait aussi fonctionner)
$internationalFlightData = [
    'departure_city' => 'Montreal',
    'departure_country' => 'Canada',
    'departure_airport_code' => 'YUL', 
    'departure_date' => '2025-12-25 10:00:00',
    'arrival_city' => 'Paris',
    'arrival_country' => 'France',
    'arrival_airport_code' => 'CDG',
    'arrival_date' => '2025-12-25 20:00:00',
    'transport_type' => 'flight',
    'flight_number' => 'AC870',
    'airline' => 'Air Canada',
    'available_weight_kg' => 20.0,
    'price_per_kg' => 35.0,
    'currency' => 'CAD',
    'description' => 'Test vol international'
];

$result2 = testApiCall($baseUrl . '/trips', 'POST', $internationalFlightData);

echo "Code de réponse: " . $result2['code'] . "\n";
if ($result2['code'] === 201) {
    echo "✅ Vol international Canada->France: AUTORISÉ\n";
} else {
    echo "❌ Vol international: erreur inattendue\n";
}

echo "\nTest terminé!\n";