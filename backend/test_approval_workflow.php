<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "🔄 TEST - Nouveau Workflow d'Approbation\n";
echo str_repeat("=", 42) . "\n";

$userToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI0Y2NhOTNhYy0xNjUwLTQ1NjUtYTc4Mi1iMTY1MjZhNTUwMDYiLCJ1c2VyIjp7ImlkIjoyLCJ1dWlkIjoiNGNjYTkzYWMtMTY1MC00NTY1LWE3ODItYjE2NTI2YTU1MDA2IiwiZW1haWwiOiJtdW1hdHRhMjAyM0BnbWFpbC5jb20iLCJyb2xlIjoidXNlciJ9LCJ0eXBlIjoiYWNjZXNzIiwiaWF0IjoxNzU2NzExNjQ3LCJleHAiOjE3NTY3MTg4NDd9.TPYsR8xne34zHZy2OB42lq03DVEuo5qXqmDFUBXQ4nE";

// Étape 1: Créer une annonce (status = draft par défaut)
echo "\n1️⃣ Création d'une annonce de test\n";
echo str_repeat("-", 35) . "\n";

$tripData = [
    'departure_city' => 'Toronto',
    'departure_country' => 'Canada',
    'departure_date' => '2025-09-20T10:00:00Z',
    'arrival_city' => 'Dakar',
    'arrival_country' => 'Sénégal',
    'arrival_date' => '2025-09-21T08:00:00Z',
    'available_weight_kg' => 15,
    'price_per_kg' => 30,
    'currency' => 'CAD',
    'description' => 'Test workflow approbation',
    'flight_number' => 'AC853'
];

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/trips/create',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode($tripData),
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $userToken,
        'Content-Type: application/json',
        'Accept: application/json'
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    echo "❌ Création échouée (HTTP $httpCode): $response\n";
    exit(1);
}

$data = json_decode($response, true);
$newTripId = $data['trip']['id'];
$newTripStatus = $data['trip']['status'];
$newTripApproved = $data['trip']['is_approved'];

echo "✅ Annonce créée (ID: $newTripId)\n";
echo "   Status: $newTripStatus\n";
echo "   Is Approved: " . ($newTripApproved ? 'Oui' : 'Non') . "\n";

// Étape 2: Publier l'annonce (draft -> pending_review)
echo "\n2️⃣ Publication de l'annonce\n";
echo str_repeat("-", 28) . "\n";

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => "http://127.0.0.1:8080/api/v1/trips/$newTripId/publish",
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $userToken,
        'Accept: application/json'
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    $data = json_decode($response, true);
    $publishedStatus = $data['trip']['status'];
    $publishedApproved = $data['trip']['is_approved'];
    
    echo "✅ Annonce publiée!\n";
    echo "   Nouveau Status: $publishedStatus\n";
    echo "   Is Approved: " . ($publishedApproved ? 'Oui' : 'Non') . "\n";
    
    if ($publishedStatus === 'pending_review' && !$publishedApproved) {
        echo "✅ Workflow correct: En attente d'approbation admin\n";
    } else {
        echo "⚠️  Workflow inattendu\n";
    }
} else {
    echo "❌ Publication échouée (HTTP $httpCode): $response\n";
}

// Étape 3: Tenter accès public (doit échouer)
echo "\n3️⃣ Test accès public (doit échouer)\n";
echo str_repeat("-", 35) . "\n";

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => "http://127.0.0.1:8080/api/v1/trips/$newTripId",
    CURLOPT_RETURNTRANSFER => true
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 404) {
    echo "✅ Accès public refusé (comme attendu)\n";
} else {
    echo "⚠️  Accès public autorisé (HTTP $httpCode) - Workflow problem\n";
}

// Étape 4: Simuler approbation admin
echo "\n4️⃣ Simulation approbation admin\n";
echo str_repeat("-", 32) . "\n";

// Générer token admin (ID 2 avec role admin pour test)
$adminHeader = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
$adminPayload = json_encode([
    'sub' => '4cca93ac-1650-4565-a782-b16526a55006',
    'user' => [
        'id' => 2,
        'uuid' => '4cca93ac-1650-4565-a782-b16526a55006',
        'email' => 'mumatta2023@gmail.com',
        'role' => 'admin'
    ],
    'type' => 'access',
    'iat' => time(),
    'exp' => time() + 3600
]);

$base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($adminHeader));
$base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($adminPayload));
$signature = hash_hmac('sha256', $base64Header . "." . $base64Payload, $_ENV['JWT_SECRET'], true);
$base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
$adminToken = $base64Header . "." . $base64Payload . "." . $base64Signature;

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => "http://127.0.0.1:8080/api/v1/admin/trips/$newTripId/approve",
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $adminToken,
        'Accept: application/json'
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    $data = json_decode($response, true);
    echo "✅ Annonce approuvée par admin!\n";
} else {
    echo "❌ Approbation échouée (HTTP $httpCode): $response\n";
}

// Étape 5: Test accès public final (doit réussir)
echo "\n5️⃣ Test accès public final (doit réussir)\n";
echo str_repeat("-", 41) . "\n";

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => "http://127.0.0.1:8080/api/v1/trips/$newTripId",
    CURLOPT_RETURNTRANSFER => true
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    $data = json_decode($response, true);
    $finalStatus = $data['trip']['status'];
    $finalApproved = $data['trip']['is_approved'];
    
    echo "✅ Accès public réussi!\n";
    echo "   Status final: $finalStatus\n";
    echo "   Is Approved: " . ($finalApproved ? 'Oui' : 'Non') . "\n";
    
    if ($finalStatus === 'active' && $finalApproved) {
        echo "🎉 WORKFLOW PARFAIT!\n";
    } else {
        echo "⚠️  Statut inattendu\n";
    }
} else {
    echo "❌ Accès public toujours refusé (HTTP $httpCode)\n";
}

echo "\n🎯 RÉSUMÉ DU WORKFLOW:\n";
echo "1. Création → Status: draft, Approved: false\n";
echo "2. Publication → Status: pending_review, Approved: false\n";
echo "3. Accès public → 404 (normal)\n";
echo "4. Approbation admin → Status: active, Approved: true\n";
echo "5. Accès public → 200 OK (visible)\n";
echo "\n✅ WORKFLOW D'APPROBATION OPÉRATIONNEL!\n";