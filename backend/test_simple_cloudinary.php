<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

use Cloudinary\Configuration\Configuration;
use Cloudinary\Api\Upload\UploadApi;

echo "🧪 Test simple Cloudinary\n";
echo str_repeat("=", 30) . "\n";

try {
    // Configuration Cloudinary
    Configuration::instance([
        'cloud_name' => $_ENV['CLOUDINARY_CLOUD_NAME'],
        'api_key' => $_ENV['CLOUDINARY_API_KEY'],
        'api_secret' => $_ENV['CLOUDINARY_API_SECRET'],
        'secure' => true
    ]);

    echo "✅ Cloud Name: " . $_ENV['CLOUDINARY_CLOUD_NAME'] . "\n";
    echo "✅ API Key: " . $_ENV['CLOUDINARY_API_KEY'] . "\n";
    
    // Test avec une image de test simple
    $testImageData = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
    
    $uploadApi = new UploadApi();
    $result = $uploadApi->upload($testImageData, [
        'upload_preset' => $_ENV['CLOUDINARY_UPLOAD_PRESET'],
        'public_id' => 'test_' . time(),
        'folder' => 'kiloshare_test'
    ]);
    
    if (isset($result['public_id'])) {
        echo "🎉 Upload test réussi !\n";
        echo "   Public ID: " . $result['public_id'] . "\n";
        echo "   URL: " . $result['secure_url'] . "\n";
        
        // Nettoyage - supprimer l'image de test
        $uploadApi->destroy($result['public_id']);
        echo "🧹 Image de test supprimée\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur : " . $e->getMessage() . "\n";
    
    if (strpos($e->getMessage(), 'Invalid upload preset') !== false) {
        echo "\n🔧 Solution :\n";
        echo "1. Allez sur https://cloudinary.com/console/settings/upload\n";
        echo "2. Cliquez 'Add upload preset'\n";
        echo "3. Nom: kiloshare_uploads\n";
        echo "4. Mode: Signed (recommandé) ou Unsigned\n";
        echo "5. Sauvegardez\n";
    }
}