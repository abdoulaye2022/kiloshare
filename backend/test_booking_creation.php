<?php

require_once __DIR__ . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

use KiloShare\Services\JWTService;

// Test de création de réservation avec JWT valide
echo "=== Test Booking Creation avec JWT ===\n";

// Configuration
$baseUrl = 'http://localhost:8000';
$testUserId = 1; // User ID pour les tests

// Créer un token JWT valide pour les tests
$jwtSettings = [
    'jwt' => [
        'secret' => $_ENV['JWT_SECRET'],
        'algorithm' => 'HS256',
        'access_expires_in' => 43200,
        'refresh_expires_in' => 604800
    ]
];

$jwtService = new JWTService($jwtSettings);
$testUserData = [
    'id' => $testUserId,
    'email' => 'test@example.com',
    'name' => 'Test User',
    'is_verified' => true
];

$token = $jwtService->generateAccessToken($testUserData);
echo "Token JWT généré: " . substr($token, 0, 50) . "...\n";

// Données de test pour la réservation
$bookingData = [
    'trip_id' => '23', // Trip existant d'après les logs Flutter
    'receiver_id' => '2', // User ID du propriétaire du voyage
    'package_description' => 'Test de réservation depuis le script PHP - documents importants',
    'weight_kg' => 2.5,
    'proposed_price' => 75.0,
    'dimensions_cm' => '30x20x10',
    'pickup_address' => '123 Test Street, Toronto, ON',
    'delivery_address' => '456 Delivery Ave, Dakar, Sénégal',
    'special_instructions' => 'Manipulation avec précaution - documents fragiles'
];

// Headers avec authentification
$headers = [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $token
];

// Test 1: Créer une réservation
echo "\n1. Test création de réservation...\n";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $baseUrl . '/api/v1/bookings/request');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($bookingData));
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_VERBOSE, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Status HTTP: $httpCode\n";
echo "Réponse: $response\n";

if ($httpCode == 201) {
    $responseData = json_decode($response, true);
    if ($responseData['success']) {
        echo "✅ Réservation créée avec succès!\n";
        $bookingId = $responseData['booking']['id'];
        echo "ID de la réservation: $bookingId\n";
        
        // Test 2: Récupérer la réservation créée
        echo "\n2. Test récupération de la réservation...\n";
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $baseUrl . '/api/v1/bookings/' . $bookingId);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        
        $getResponse = curl_exec($ch);
        $getHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        echo "Status HTTP: $getHttpCode\n";
        echo "Réponse: $getResponse\n";
        
        if ($getHttpCode == 200) {
            echo "✅ Récupération réussie!\n";
        } else {
            echo "❌ Échec de la récupération\n";
        }
        
    } else {
        echo "❌ Erreur dans la création: " . $responseData['error'] . "\n";
    }
} else {
    echo "❌ Échec de la création - Status: $httpCode\n";
    if ($response) {
        $errorData = json_decode($response, true);
        if ($errorData && isset($errorData['error'])) {
            echo "Erreur: " . $errorData['error'] . "\n";
        }
    }
}

echo "\n=== Fin du test ===\n";