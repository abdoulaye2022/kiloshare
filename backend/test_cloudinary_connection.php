<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

use Cloudinary\Configuration\Configuration;
use Cloudinary\Api\Admin\AdminApi;

echo "🧪 Test de connexion Cloudinary pour KiloShare\n";
echo str_repeat("=", 50) . "\n";

try {
    // Configuration Cloudinary
    $config = Configuration::instance([
        'cloud_name' => $_ENV['CLOUDINARY_CLOUD_NAME'] ?? '',
        'api_key' => $_ENV['CLOUDINARY_API_KEY'] ?? '',
        'api_secret' => $_ENV['CLOUDINARY_API_SECRET'] ?? '',
        'secure' => true
    ]);

    echo "✅ Configuration chargée :\n";
    echo "   Cloud Name: " . ($_ENV['CLOUDINARY_CLOUD_NAME'] ?? 'NON DÉFINI') . "\n";
    echo "   API Key: " . ($_ENV['CLOUDINARY_API_KEY'] ?? 'NON DÉFINI') . "\n";
    echo "   API Secret: " . (($_ENV['CLOUDINARY_API_SECRET'] ?? '') ? '***' . substr($_ENV['CLOUDINARY_API_SECRET'], -4) : 'NON DÉFINI') . "\n";
    echo "   Upload Preset: " . ($_ENV['CLOUDINARY_UPLOAD_PRESET'] ?? 'NON DÉFINI') . "\n\n";

    // Test de connexion avec l'API Admin
    $adminApi = new AdminApi();
    $ping = $adminApi->ping();
    
    if ($ping && isset($ping['status']) && $ping['status'] === 'ok') {
        echo "🎉 Connexion Cloudinary réussie !\n";
        echo "   Status: " . $ping['status'] . "\n\n";
    } else {
        echo "❌ Réponse ping inattendue : " . json_encode($ping) . "\n\n";
    }

    // Test des upload presets
    echo "📋 Vérification des upload presets...\n";
    $presets = $adminApi->listUploadPresets(['max_results' => 50]);
    
    if (isset($presets['presets'])) {
        echo "   Presets disponibles :\n";
        $foundKiloshare = false;
        
        foreach ($presets['presets'] as $preset) {
            $name = $preset['name'] ?? 'unnamed';
            $mode = $preset['unsigned'] ? 'unsigned' : 'signed';
            echo "   - $name ($mode)\n";
            
            if ($name === 'kiloshare_uploads') {
                $foundKiloshare = true;
                echo "     ✅ Preset KiloShare trouvé !\n";
            }
        }
        
        if (!$foundKiloshare) {
            echo "   ⚠️  Preset 'kiloshare_uploads' introuvable.\n";
            echo "   🔧 Créez-le dans le dashboard Cloudinary :\n";
            echo "      1. Allez sur https://cloudinary.com/console/settings/upload\n";
            echo "      2. Cliquez 'Add upload preset'\n";
            echo "      3. Nom: kiloshare_uploads\n";
            echo "      4. Mode: Signed\n";
            echo "      5. Sauvegardez\n";
        }
        
    } else {
        echo "   ❌ Impossible de récupérer les presets\n";
    }

    echo "\n📊 Informations du compte...\n";
    $usage = $adminApi->usage();
    
    if (isset($usage['credits'])) {
        $credits = $usage['credits'];
        $used = $credits['used'] ?? 0;
        $limit = $credits['limit'] ?? 0;
        $percentage = $limit > 0 ? round(($used / $limit) * 100, 1) : 0;
        
        echo "   Credits utilisés: $used / $limit ($percentage%)\n";
    }
    
    if (isset($usage['bandwidth'])) {
        $bandwidth = $usage['bandwidth'];
        $used = round(($bandwidth['used'] ?? 0) / 1024 / 1024, 2);
        $limit = round(($bandwidth['limit'] ?? 0) / 1024 / 1024, 2);
        $percentage = $limit > 0 ? round(($bandwidth['used'] / $bandwidth['limit']) * 100, 1) : 0;
        
        echo "   Bande passante: {$used}MB / {$limit}MB ($percentage%)\n";
    }
    
    if (isset($usage['storage'])) {
        $storage = $usage['storage'];
        $used = round(($storage['used'] ?? 0) / 1024 / 1024, 2);
        $limit = round(($storage['limit'] ?? 0) / 1024 / 1024, 2);
        $percentage = $limit > 0 ? round(($storage['used'] / $storage['limit']) * 100, 1) : 0;
        
        echo "   Stockage: {$used}MB / {$limit}MB ($percentage%)\n";
    }
    
    echo "\n✅ Test de connexion Cloudinary terminé avec succès !\n";
    
} catch (Exception $e) {
    echo "❌ Erreur lors du test de connexion :\n";
    echo "   " . $e->getMessage() . "\n";
    echo "\n🔧 Vérifiez :\n";
    echo "   1. Les variables d'environnement dans .env\n";
    echo "   2. Vos identifiants Cloudinary\n";
    echo "   3. Votre connexion internet\n";
    
    exit(1);
}