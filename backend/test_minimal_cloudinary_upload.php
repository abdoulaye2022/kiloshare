<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

use Cloudinary\Configuration\Configuration;
use Cloudinary\Api\Upload\UploadApi;

echo "🧪 Test upload Cloudinary minimal\n";
echo str_repeat("=", 35) . "\n";

try {
    // Configuration simple
    Configuration::instance([
        'cloud' => [
            'cloud_name' => $_ENV['CLOUDINARY_CLOUD_NAME'],
            'api_key' => $_ENV['CLOUDINARY_API_KEY'],
            'api_secret' => $_ENV['CLOUDINARY_API_SECRET'],
        ],
        'url' => [
            'secure' => true
        ]
    ]);
    
    echo "✅ Configuration OK\n";

    // Créer une image de test
    $image = imagecreate(100, 100);
    $backgroundColor = imagecolorallocate($image, 200, 100, 150);
    $textColor = imagecolorallocate($image, 255, 255, 255);
    imagestring($image, 4, 10, 40, 'TEST', $textColor);

    $tempFile = '/tmp/test_minimal.jpg';
    imagejpeg($image, $tempFile);
    imagedestroy($image);
    
    echo "✅ Image créée: $tempFile\n";

    // Upload avec options TRÈS simples
    $uploadApi = new UploadApi();
    
    $basicOptions = [
        'public_id' => 'test_minimal_' . time(),
        'resource_type' => 'image',
        'type' => 'upload'
    ];
    
    echo "📤 Upload avec options minimales...\n";
    echo "Options: " . json_encode($basicOptions, JSON_PRETTY_PRINT) . "\n";
    
    $result = $uploadApi->upload($tempFile, $basicOptions);
    
    if (isset($result['public_id'])) {
        echo "🎉 Upload réussi !\n";
        echo "   Public ID: " . $result['public_id'] . "\n";
        echo "   URL: " . $result['secure_url'] . "\n";
        
        // Nettoyage
        $uploadApi->destroy($result['public_id']);
        echo "🧹 Image supprimée\n";
    }
    
    unlink($tempFile);
    echo "✅ Fichier temporaire supprimé\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getFile() . ":" . $e->getLine() . "\n";
    
    if (file_exists('/tmp/test_minimal.jpg')) {
        unlink('/tmp/test_minimal.jpg');
    }
}