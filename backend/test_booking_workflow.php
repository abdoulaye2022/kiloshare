<?php

require_once __DIR__ . '/vendor/autoload.php';

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

use KiloShare\Services\JWTService;

echo "=== Test Workflow Complet des Réservations KiloShare ===\n";

$baseUrl = 'http://localhost:8000';

// Créer des tokens JWT pour 2 utilisateurs différents
$jwtSettings = [
    'jwt' => [
        'secret' => $_ENV['JWT_SECRET'],
        'algorithm' => 'HS256',
        'access_expires_in' => 43200,
        'refresh_expires_in' => 604800
    ]
];

$jwtService = new JWTService($jwtSettings);

// User 1 - Expéditeur (celui qui fait la demande)
$sender = [
    'id' => 1,
    'email' => 'sender@example.com',
    'name' => 'Alice Sender',
    'is_verified' => true
];

$senderToken = $jwtService->generateAccessToken($sender);

// User 2 - Transporteur (propriétaire du voyage)
$receiver = [
    'id' => 2,
    'email' => 'receiver@example.com',
    'name' => 'Bob Transporter',
    'is_verified' => true
];

$receiverToken = $jwtService->generateAccessToken($receiver);

echo "Token expéditeur: " . substr($senderToken, 0, 50) . "...\n";
echo "Token transporteur: " . substr($receiverToken, 0, 50) . "...\n\n";

// Étape 1: Créer une demande de réservation (par l'expéditeur)
echo "== ÉTAPE 1: Création de la réservation ==\n";

$bookingData = [
    'trip_id' => '23',
    'receiver_id' => '2',
    'package_description' => 'Documents importants et cadeau d\'anniversaire',
    'weight_kg' => 3.5,
    'proposed_price' => 105.0,
    'dimensions_cm' => '40x30x15',
    'pickup_address' => '456 Rue Principale, Toronto, ON M5V 3A8',
    'delivery_address' => '789 Avenue de l\'Indépendance, Dakar, Sénégal',
    'special_instructions' => 'Fragile - contient des documents importants et un cadeau. Merci de manipuler avec précaution.'
];

$result = makeApiCall('POST', '/api/v1/bookings/request', $senderToken, $bookingData);

if ($result['success']) {
    $bookingId = $result['booking']['id'];
    echo "✅ Réservation créée avec succès! ID: $bookingId\n";
    echo "   Statut: {$result['booking']['status']}\n";
    echo "   Prix proposé: {$result['booking']['proposed_price']} CAD\n\n";
} else {
    echo "❌ Échec de la création: " . $result['error'] . "\n";
    exit(1);
}

// Étape 2: Lister les réservations reçues par le transporteur
echo "== ÉTAPE 2: Récupération des réservations reçues ==\n";

$result = makeApiCall('GET', '/api/v1/bookings/list?role=receiver', $receiverToken);

if ($result['success'] && !empty($result['bookings'])) {
    echo "✅ Réservations trouvées: " . count($result['bookings']) . "\n";
    foreach ($result['bookings'] as $booking) {
        echo "   - Réservation #{$booking['id']}: {$booking['status']} - {$booking['proposed_price']} CAD\n";
    }
    echo "\n";
} else {
    echo "❌ Pas de réservations trouvées ou erreur\n\n";
}

// Étape 3: Négociation de prix par le transporteur
echo "== ÉTAPE 3: Négociation de prix ==\n";

$negotiationData = [
    'amount' => 85.0,
    'message' => 'Je peux vous proposer 85 CAD pour ce transport. Le prix me semble plus adapté au poids et à la destination.'
];

$result = makeApiCall('POST', "/api/v1/bookings/$bookingId/negotiate", $receiverToken, $negotiationData);

if ($result['success']) {
    echo "✅ Négociation envoyée: 85 CAD\n";
    echo "   Message: {$negotiationData['message']}\n\n";
} else {
    echo "❌ Échec de la négociation: " . $result['error'] . "\n\n";
}

// Étape 4: Acceptation de la réservation par le transporteur avec prix négocié
echo "== ÉTAPE 4: Acceptation de la réservation ==\n";

$acceptData = ['final_price' => 90.0]; // Prix de compromis

$result = makeApiCall('PUT', "/api/v1/bookings/$bookingId/accept", $receiverToken, $acceptData);

if ($result['success']) {
    echo "✅ Réservation acceptée avec succès!\n";
    echo "   Nouveau statut: {$result['booking']['status']}\n";
    echo "   Prix final: {$result['booking']['final_price']} CAD\n\n";
} else {
    echo "❌ Échec de l'acceptation: " . $result['error'] . "\n\n";
}

// Étape 5: Marquer comme prêt pour paiement
echo "== ÉTAPE 5: Marquage prêt pour paiement ==\n";

$result = makeApiCall('PUT', "/api/v1/bookings/$bookingId/payment-ready", $receiverToken);

if ($result['success']) {
    echo "✅ Marqué comme prêt pour paiement\n\n";
} else {
    echo "❌ Échec du marquage: " . $result['error'] . "\n\n";
}

// Étape 6: Récupérer les détails finaux de la réservation
echo "== ÉTAPE 6: Détails finaux de la réservation ==\n";

$result = makeApiCall('GET', "/api/v1/bookings/$bookingId", $senderToken);

if ($result['success']) {
    $booking = $result['booking'];
    echo "✅ Réservation finale:\n";
    echo "   ID: {$booking['id']}\n";
    echo "   Statut: {$booking['status']}\n";
    echo "   Route: {$booking['departure_city']} → {$booking['arrival_city']}\n";
    echo "   Colis: {$booking['package_description']}\n";
    echo "   Poids: {$booking['weight_kg']} kg\n";
    echo "   Prix proposé: {$booking['proposed_price']} CAD\n";
    echo "   Prix final: " . ($booking['final_price'] ?? 'Non défini') . " CAD\n";
    echo "   Expéditeur: {$booking['sender_first_name']} ({$booking['sender_email']})\n";
    echo "   Transporteur: {$booking['receiver_first_name']} ({$booking['receiver_email']})\n";
    echo "   Collecte: {$booking['pickup_address']}\n";
    echo "   Livraison: {$booking['delivery_address']}\n";
    echo "   Instructions: {$booking['special_instructions']}\n";
    echo "   Créée: {$booking['created_at']}\n";
    echo "   Mise à jour: {$booking['updated_at']}\n";
    echo "   Expire: {$booking['expires_at']}\n";
    echo "\n";
} else {
    echo "❌ Échec de la récupération: " . $result['error'] . "\n\n";
}

// Test de rejet d'une nouvelle réservation
echo "== BONUS: Test de rejet de réservation ==\n";

$rejectBookingData = [
    'trip_id' => '23',
    'receiver_id' => '2',
    'package_description' => 'Colis à rejeter pour test',
    'weight_kg' => 1.0,
    'proposed_price' => 25.0,
];

$result = makeApiCall('POST', '/api/v1/bookings/request', $senderToken, $rejectBookingData);

if ($result['success']) {
    $rejectBookingId = $result['booking']['id'];
    echo "✅ Réservation de test créée: $rejectBookingId\n";
    
    // Rejeter immédiatement
    $result = makeApiCall('PUT', "/api/v1/bookings/$rejectBookingId/reject", $receiverToken);
    
    if ($result['success']) {
        echo "✅ Réservation rejetée avec succès\n";
    } else {
        echo "❌ Échec du rejet: " . $result['error'] . "\n";
    }
} else {
    echo "❌ Échec de création de la réservation de test\n";
}

echo "\n=== Workflow terminé avec succès! ===\n";

function makeApiCall($method, $endpoint, $token, $data = null) {
    global $baseUrl;
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $baseUrl . $endpoint);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $token
    ]);
    
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    } elseif ($method === 'PUT') {
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    } elseif ($method === 'DELETE') {
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($response === false) {
        return ['success' => false, 'error' => 'Curl error'];
    }
    
    $decoded = json_decode($response, true);
    if ($decoded === null) {
        return ['success' => false, 'error' => 'Invalid JSON response'];
    }
    
    // Ajouter le code HTTP à la réponse pour debug
    $decoded['http_code'] = $httpCode;
    
    return $decoded;
}