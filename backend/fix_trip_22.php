<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "🔧 Correction du Trip 22\n";
echo str_repeat("=", 25) . "\n";

try {
    $pdo = new PDO(
        "mysql:host={$_ENV['DB_HOST']};dbname={$_ENV['DB_NAME']};charset=utf8mb4",
        $_ENV['DB_USER'],
        $_ENV['DB_PASSWORD'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    // État actuel
    $stmt = $pdo->prepare("SELECT id, user_id, status, is_approved, departure_city, arrival_city FROM trips WHERE id = ?");
    $stmt->execute([22]);
    $trip = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($trip) {
        echo "📋 État actuel du Trip 22:\n";
        echo "   Status: " . $trip['status'] . "\n";
        echo "   Is Approved: " . ($trip['is_approved'] ? 'Oui' : 'Non') . "\n";
        echo "   Route: " . $trip['departure_city'] . " → " . $trip['arrival_city'] . "\n";
        
        // Corriger le trip pour qu'il soit approuvé
        $stmt = $pdo->prepare("
            UPDATE trips 
            SET status = 'active', is_approved = 1, moderated_by = 2
            WHERE id = ?
        ");
        $stmt->execute([22]);
        
        echo "\n✅ Trip 22 corrigé!\n";
        
        // Vérifier les changements
        $stmt = $pdo->prepare("SELECT id, user_id, status, is_approved FROM trips WHERE id = ?");
        $stmt->execute([22]);
        $updatedTrip = $stmt->fetch(PDO::FETCH_ASSOC);
        
        echo "📋 Nouvel état du Trip 22:\n";
        echo "   Status: " . $updatedTrip['status'] . "\n";
        echo "   Is Approved: " . ($updatedTrip['is_approved'] ? 'Oui' : 'Non') . "\n";
        
        // Test d'accès
        echo "\n🧪 Test d'accès public...\n";
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => 'http://127.0.0.1:8080/api/v1/trips/22',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 5,
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            echo "✅ Trip 22 maintenant accessible au public!\n";
        } else {
            echo "❌ Toujours pas accessible (HTTP $httpCode)\n";
        }
        
    } else {
        echo "❌ Trip 22 n'existe pas\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}