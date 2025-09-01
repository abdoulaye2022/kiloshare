<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "🧪 Test upload avatar avec authentification\n";
echo str_repeat("=", 40) . "\n";

// Créer une image de test
$image = imagecreate(200, 200);
$backgroundColor = imagecolorallocate($image, 100, 150, 200);
$textColor = imagecolorallocate($image, 255, 255, 255);
imagestring($image, 5, 50, 90, 'AVATAR', $textColor);
imagestring($image, 3, 60, 120, 'TEST', $textColor);

$tempFile = '/tmp/test_avatar.jpg';
imagejpeg($image, $tempFile);
imagedestroy($image);

echo "✅ Image de test créée: $tempFile\n";

// Créer un token JWT simple pour test (normalement fait par l'auth)
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
    'exp' => time() + 3600
]);

$base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
$base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));

$signature = hash_hmac('sha256', $base64Header . "." . $base64Payload, $_ENV['JWT_SECRET'], true);
$base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

$token = $base64Header . "." . $base64Payload . "." . $base64Signature;

echo "✅ Token JWT généré pour test\n";

// Test avec cURL
$ch = curl_init();

curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/images/avatar',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => [
        'avatar' => new CURLFile($tempFile, 'image/jpeg', 'test_avatar.jpg')
    ],
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $token,
        'Accept: application/json'
    ]
]);

echo "📤 Test upload vers l'endpoint...\n";

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

echo "Code HTTP: $httpCode\n";
echo "Réponse: $response\n";

if ($httpCode === 200) {
    $data = json_decode($response, true);
    if ($data && $data['success']) {
        echo "🎉 Upload réussi !\n";
        if (isset($data['data']['cloudinary_url'])) {
            echo "🔗 URL Cloudinary: " . $data['data']['cloudinary_url'] . "\n";
        }
    }
} else {
    echo "❌ Upload échoué\n";
}

curl_close($ch);

// Nettoyer
unlink($tempFile);

echo "✅ Test terminé\n";