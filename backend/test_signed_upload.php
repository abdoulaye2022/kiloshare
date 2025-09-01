<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

use Cloudinary\Configuration\Configuration;
use Cloudinary\Api\Upload\UploadApi;

echo "🧪 Test upload signé Cloudinary (sans preset)\n";
echo str_repeat("=", 40) . "\n";

try {
    // Configuration Cloudinary
    Configuration::instance([
        'cloud_name' => $_ENV['CLOUDINARY_CLOUD_NAME'],
        'api_key' => $_ENV['CLOUDINARY_API_KEY'],
        'api_secret' => $_ENV['CLOUDINARY_API_SECRET'],
        'secure' => true
    ]);

    echo "✅ Configuration OK\n";
    
    // Test avec une image de test simple - SANS upload_preset
    $testImageData = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
    
    $uploadApi = new UploadApi();
    $result = $uploadApi->upload($testImageData, [
        'public_id' => 'kiloshare_test_' . time(),
        'folder' => 'kiloshare/test',
        'resource_type' => 'image',
        'type' => 'upload'
    ]);
    
    if (isset($result['public_id'])) {
        echo "🎉 Upload signé réussi !\n";
        echo "   Public ID: " . $result['public_id'] . "\n";
        echo "   URL: " . $result['secure_url'] . "\n";
        echo "   Format: " . $result['format'] . "\n";
        echo "   Taille: " . $result['width'] . "x" . $result['height'] . "\n";
        
        // Nettoyage - supprimer l'image de test
        $uploadApi->destroy($result['public_id']);
        echo "🧹 Image de test supprimée\n";
        
        echo "\n✅ Cloudinary fonctionne parfaitement !\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur : " . $e->getMessage() . "\n";
    echo "Stack: " . $e->getTraceAsString() . "\n";
}