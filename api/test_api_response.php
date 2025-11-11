<?php

$ch = curl_init();

// 1. Login pour obtenir un token
curl_setopt($ch, CURLOPT_URL, "http://127.0.0.1:8080/api/v1/auth/login");
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'email' => 'ali@gmail.com',
    'password' => 'password'
]));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$loginData = json_decode($response, true);

echo "=== LOGIN RESPONSE ===\n";
if (isset($loginData['data']['user'])) {
    $user = $loginData['data']['user'];
    echo "profile_picture: " . ($user['profile_picture'] ?? 'null') . "\n";
    echo "profile_picture_url: " . ($user['profile_picture_url'] ?? 'null') . "\n";
}

if (!isset($loginData['data']['tokens']['access_token'])) {
    echo "Login failed: " . json_encode($loginData) . "\n";
    exit(1);
}

$token = $loginData['data']['tokens']['access_token'];

// 2. Appeler /me pour voir les données retournées
curl_setopt($ch, CURLOPT_URL, "http://127.0.0.1:8080/api/v1/auth/me");
curl_setopt($ch, CURLOPT_POST, 0);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $token
]);

$response = curl_exec($ch);
$meData = json_decode($response, true);

echo "\n=== ME RESPONSE ===\n";
if (isset($meData['data'])) {
    $user = $meData['data'];
    echo "profile_picture: " . ($user['profile_picture'] ?? 'null') . "\n";
    echo "profile_picture_url: " . ($user['profile_picture_url'] ?? 'null') . "\n";
}

// 3. Appeler /user/profile
curl_setopt($ch, CURLOPT_URL, "http://127.0.0.1:8080/api/v1/user/profile");
curl_setopt($ch, CURLOPT_POST, 0);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $token
]);

$response = curl_exec($ch);
$profileData = json_decode($response, true);

echo "\n=== USER/PROFILE RESPONSE ===\n";
if (isset($profileData['data']['user'])) {
    $user = $profileData['data']['user'];
    echo "profile_picture: " . ($user['profile_picture'] ?? 'null') . "\n";
    echo "profile_picture_url: " . ($user['profile_picture_url'] ?? 'null') . "\n";
}

curl_close($ch);

echo "\n✅ Test terminé\n";