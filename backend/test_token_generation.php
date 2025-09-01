<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "🔐 Génération d'un nouveau token JWT\n";
echo str_repeat("=", 35) . "\n";

// Générer un token JWT avec une expiration longue pour les tests
$header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
$payload = json_encode([
    'sub' => '4cca93ac-1650-4565-a782-b16526a55006',
    'user' => [
        'id' => 2,
        'uuid' => '4cca93ac-1650-4565-a782-b16526a55006',
        'email' => 'mumatta2023@gmail.com',
        'role' => 'user'
    ],
    'type' => 'access',
    'iat' => time(),
    'exp' => time() + 7200 // 2 heures
]);

$base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
$base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
$signature = hash_hmac('sha256', $base64Header . "." . $base64Payload, $_ENV['JWT_SECRET'], true);
$base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

$newToken = $base64Header . "." . $base64Payload . "." . $base64Signature;

echo "✅ Nouveau token généré:\n";
echo $newToken . "\n\n";

// Test le token avec l'API
echo "🧪 Test du token avec l'API...\n";
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/auth/me',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $newToken,
        'Accept: application/json'
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    $data = json_decode($response, true);
    echo "✅ Token valide! Utilisateur: " . ($data['user']['email'] ?? 'N/A') . "\n";
} else {
    echo "❌ Token invalide (HTTP $httpCode)\n";
}

echo "\n🎯 Utilisez ce token pour vos tests Flutter:\n";
echo "Authorization: Bearer $newToken\n";