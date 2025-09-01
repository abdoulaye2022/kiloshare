<?php

// Script pour créer une image temporaire et tester l'endpoint avatar

// Créer une image de test simple
$image = imagecreate(100, 100);
$backgroundColor = imagecolorallocate($image, 255, 255, 255);
$textColor = imagecolorallocate($image, 0, 0, 0);
imagestring($image, 5, 10, 40, 'TEST', $textColor);

$tempFile = '/tmp/test_avatar.jpg';
imagejpeg($image, $tempFile);
imagedestroy($image);

echo "Image de test créée : $tempFile\n";

// Test avec cURL
$ch = curl_init();

// D'abord, se connecter pour obtenir un token
$loginData = json_encode([
    'email' => 'mumatta2023@gmail.com',
    'password' => 'your_password_here' // Remplacez par le bon mot de passe
]);

curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/auth/google', // Utilisons l'auth Google
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode(['access_token' => 'fake_token']),
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'Accept: application/json'
    ]
]);

echo "Test de l'endpoint sans authentification d'abord...\n";

// Test direct de l'endpoint avatar
curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/images/avatar',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => [
        'avatar' => new CURLFile($tempFile, 'image/jpeg', 'test_avatar.jpg')
    ],
    CURLOPT_HTTPHEADER => [
        'Accept: application/json'
        // Pas d'auth pour voir l'erreur
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

echo "Code HTTP: $httpCode\n";
echo "Réponse: $response\n";

curl_close($ch);

// Nettoyer
unlink($tempFile);

echo "✅ Test terminé\n";