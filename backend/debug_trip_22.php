<?php

require __DIR__ . '/vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

echo "🔍 Debug Trip ID 22\n";
echo str_repeat("=", 25) . "\n";

try {
    $pdo = new PDO(
        "mysql:host={$_ENV['DB_HOST']};dbname={$_ENV['DB_NAME']};charset=utf8mb4",
        $_ENV['DB_USER'],
        $_ENV['DB_PASSWORD'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    // Vérifier si le trip 22 existe
    $stmt = $pdo->prepare("SELECT id, user_id, status, is_approved, departure_city, arrival_city, created_at FROM trips WHERE id = ?");
    $stmt->execute([22]);
    $trip = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($trip) {
        echo "✅ Trip trouvé:\n";
        echo "   ID: " . $trip['id'] . "\n";
        echo "   User ID: " . $trip['user_id'] . "\n";
        echo "   Status: " . $trip['status'] . "\n";
        echo "   Is Approved: " . ($trip['is_approved'] ? 'Oui' : 'Non') . "\n";
        echo "   Route: " . $trip['departure_city'] . " → " . $trip['arrival_city'] . "\n";
        echo "   Créé: " . $trip['created_at'] . "\n";
        
        // Vérifier les conditions d'accès
        echo "\n🔐 Conditions d'accès:\n";
        $allowedStatuses = ['active', 'published'];
        
        if ($trip['is_approved'] && in_array($trip['status'], $allowedStatuses)) {
            echo "✅ Trip accessible au public\n";
        } else {
            echo "❌ Trip NON accessible au public:\n";
            if (!$trip['is_approved']) {
                echo "   - Pas encore approuvé\n";
            }
            if (!in_array($trip['status'], $allowedStatuses)) {
                echo "   - Status '{$trip['status']}' pas dans [active, published]\n";
            }
        }
        
    } else {
        echo "❌ Trip 22 n'existe pas\n";
    }
    
    // Lister quelques trips publics pour comparaison
    echo "\n📋 Quelques trips publics:\n";
    $stmt = $pdo->prepare("SELECT id, user_id, status, is_approved, departure_city, arrival_city FROM trips WHERE is_approved = 1 AND status IN ('active', 'published') LIMIT 3");
    $stmt->execute();
    $publicTrips = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($publicTrips as $t) {
        echo "   Trip {$t['id']}: {$t['departure_city']} → {$t['arrival_city']} (User {$t['user_id']}, {$t['status']})\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}