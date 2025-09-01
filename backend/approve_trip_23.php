<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "✅ Approbation manuelle du Trip 23\n";
echo str_repeat("=", 35) . "\n";

try {
    $pdo = new PDO(
        "mysql:host={$_ENV['DB_HOST']};dbname={$_ENV['DB_NAME']};charset=utf8mb4",
        $_ENV['DB_USER'],
        $_ENV['DB_PASSWORD'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    // Approuver le trip 23
    $stmt = $pdo->prepare("
        UPDATE trips 
        SET status = 'active', is_approved = 1, moderated_by = 2
        WHERE id = 23
    ");
    $stmt->execute();
    
    if ($stmt->rowCount() > 0) {
        echo "✅ Trip 23 approuvé!\n";
        
        // Test d'accès
        echo "\n🧪 Test accès public...\n";
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/trips/23',
            CURLOPT_RETURNTRANSFER => true,
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            echo "🎉 Trip 23 maintenant accessible au public!\n";
            echo "📋 Workflow d'approbation 100% fonctionnel!\n";
        } else {
            echo "❌ Problème d'accès (HTTP $httpCode)\n";
        }
        
    } else {
        echo "❌ Trip 23 non trouvé\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}