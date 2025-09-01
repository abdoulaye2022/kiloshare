<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "🧪 Test d'organisation des dossiers Cloudinary\n";
echo str_repeat("=", 45) . "\n";

// Test 1: Upload Avatar (doit aller dans avatars/)
echo "\n1️⃣ Test Upload Avatar\n";
echo str_repeat("-", 25) . "\n";

// Créer une image de test pour avatar
$image = imagecreate(150, 150);
$backgroundColor = imagecolorallocate($image, 100, 150, 200);
$textColor = imagecolorallocate($image, 255, 255, 255);
imagestring($image, 5, 40, 65, 'AVATAR', $textColor);

$tempAvatarFile = '/tmp/test_avatar_folder.jpg';
imagejpeg($image, $tempAvatarFile);
imagedestroy($image);

// Créer un token JWT simple pour test
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

// Test upload avatar
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/images/avatar',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => [
        'avatar' => new CURLFile($tempAvatarFile, 'image/jpeg', 'test_avatar_folder.jpg')
    ],
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $token,
        'Accept: application/json'
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Code HTTP: $httpCode\n";
if ($httpCode === 200) {
    $data = json_decode($response, true);
    if ($data && $data['success']) {
        echo "✅ Avatar uploadé avec succès!\n";
        $avatarUrl = $data['data']['avatar_url'] ?? '';
        echo "🔗 URL: $avatarUrl\n";
        
        // Vérifier si l'URL contient 'avatars/'
        if (strpos($avatarUrl, '/avatars/') !== false) {
            echo "✅ Dossier correct: avatars/\n";
        } else {
            echo "❌ Erreur: pas dans le dossier avatars/\n";
        }
    }
} else {
    echo "❌ Erreur upload avatar: $response\n";
}

unlink($tempAvatarFile);

// Test 2: Upload Trip Photos (doit aller dans trips/)
echo "\n2️⃣ Test Upload Photos de Voyage\n";
echo str_repeat("-", 32) . "\n";

// Créer 2 images de test pour voyage
$tripImages = [];
for ($i = 1; $i <= 2; $i++) {
    $image = imagecreate(300, 200);
    $backgroundColor = imagecolorallocate($image, 50, 150, 100);
    $textColor = imagecolorallocate($image, 255, 255, 255);
    imagestring($image, 5, 100, 90, "TRIP $i", $textColor);
    
    $tempFile = "/tmp/test_trip_$i.jpg";
    imagejpeg($image, $tempFile);
    imagedestroy($image);
    $tripImages[] = $tempFile;
}

// Test upload trip photos avec curl en multipart
$boundary = '----formdata-' . uniqid();
$postData = '';

// Ajouter trip_id
$postData .= "--$boundary\r\n";
$postData .= "Content-Disposition: form-data; name=\"trip_id\"\r\n\r\n";
$postData .= "123\r\n";

// Ajouter chaque image
foreach ($tripImages as $index => $imagePath) {
    $fileData = file_get_contents($imagePath);
    $filename = basename($imagePath);
    
    $postData .= "--$boundary\r\n";
    $postData .= "Content-Disposition: form-data; name=\"photos[]\"; filename=\"$filename\"\r\n";
    $postData .= "Content-Type: image/jpeg\r\n\r\n";
    $postData .= $fileData . "\r\n";
}

$postData .= "--$boundary--\r\n";

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/images/trip',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => $postData,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $token,
        'Accept: application/json',
        'Content-Type: multipart/form-data; boundary=' . $boundary,
        'Content-Length: ' . strlen($postData)
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

echo "Code HTTP: $httpCode\n";
if ($curlError) {
    echo "❌ Erreur cURL: $curlError\n";
}

if ($httpCode === 200) {
    $data = json_decode($response, true);
    if ($data && $data['success']) {
        echo "✅ Photos de voyage uploadées avec succès!\n";
        echo "📸 Nombre de photos: " . count($data['data']['photos'] ?? []) . "\n";
        
        // Vérifier chaque URL
        foreach ($data['data']['photos'] ?? [] as $photo) {
            $photoUrl = $photo['photo_url'] ?? '';
            echo "🔗 URL: $photoUrl\n";
            
            if (strpos($photoUrl, '/trips/') !== false) {
                echo "✅ Dossier correct: trips/\n";
            } else {
                echo "❌ Erreur: pas dans le dossier trips/\n";
            }
        }
    } else {
        echo "❌ Erreur dans la réponse: " . ($data['message'] ?? 'Unknown') . "\n";
    }
} else {
    echo "❌ Erreur upload photos voyage (HTTP $httpCode): $response\n";
}

// Nettoyer les fichiers temporaires
foreach ($tripImages as $imagePath) {
    if (file_exists($imagePath)) {
        unlink($imagePath);
    }
}

// Test 3: Upload Document KYC (doit aller dans kyc/)
echo "\n3️⃣ Test Upload Document KYC\n";
echo str_repeat("-", 28) . "\n";

// Créer une image de test pour document
$image = imagecreate(400, 300);
$backgroundColor = imagecolorallocate($image, 200, 200, 200);
$textColor = imagecolorallocate($image, 0, 0, 0);
imagestring($image, 5, 120, 140, 'PASSPORT', $textColor);

$tempKycFile = '/tmp/test_kyc_doc.jpg';
imagejpeg($image, $tempKycFile);
imagedestroy($image);

// Test upload KYC document
$postData = '';
$boundary = '----formdata-' . uniqid();

// Ajouter document_type
$postData .= "--$boundary\r\n";
$postData .= "Content-Disposition: form-data; name=\"document_type\"\r\n\r\n";
$postData .= "passport\r\n";

// Ajouter le document
$fileData = file_get_contents($tempKycFile);
$filename = basename($tempKycFile);

$postData .= "--$boundary\r\n";
$postData .= "Content-Disposition: form-data; name=\"document\"; filename=\"$filename\"\r\n";
$postData .= "Content-Type: image/jpeg\r\n\r\n";
$postData .= $fileData . "\r\n";

$postData .= "--$boundary--\r\n";

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/images/kyc',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => $postData,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $token,
        'Accept: application/json',
        'Content-Type: multipart/form-data; boundary=' . $boundary,
        'Content-Length: ' . strlen($postData)
    ]
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Code HTTP: $httpCode\n";
if ($httpCode === 200) {
    $data = json_decode($response, true);
    if ($data && $data['success']) {
        echo "✅ Document KYC uploadé avec succès!\n";
        $kycUrl = $data['data']['document_url'] ?? '';
        echo "🔗 URL: $kycUrl\n";
        
        // Vérifier si l'URL contient 'kyc/'
        if (strpos($kycUrl, '/kyc/') !== false) {
            echo "✅ Dossier correct: kyc/\n";
        } else {
            echo "❌ Erreur: pas dans le dossier kyc/\n";
        }
    }
} else {
    echo "❌ Erreur upload KYC: $response\n";
}

unlink($tempKycFile);

echo "\n🎯 Résumé du test d'organisation des dossiers:\n";
echo "- Avatar: doit être dans avatars/user_2/\n";
echo "- Photos voyage: doit être dans trips/trip_123/user_2/\n";
echo "- Document KYC: doit être dans kyc/user_2/\n";
echo "\n✅ Test terminé\n";