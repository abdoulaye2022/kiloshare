<?php
require_once __DIR__ . '/vendor/autoload.php';

// Test de validation du voyage ID 19 directement via la base de données

use src\Config\Database;

try {
    $database = new Database();
    $pdo = $database->getConnection();
    
    echo "=== Debug Voyage ID 19 ===\n\n";
    
    // Récupérer les données du voyage
    $stmt = $pdo->prepare("
        SELECT * FROM trips WHERE id = ? LIMIT 1
    ");
    $stmt->execute([19]);
    $tripData = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$tripData) {
        echo "❌ Voyage ID 19 non trouvé!\n";
        exit(1);
    }
    
    echo "✅ Voyage trouvé:\n";
    echo "- Status: {$tripData['status']}\n";
    echo "- Départ: {$tripData['departure_city']} ({$tripData['departure_country']})\n";  
    echo "- Arrivée: {$tripData['arrival_city']} ({$tripData['arrival_country']})\n";
    echo "- Transport: ";
    
    $isFlightTransport = !empty($tripData['flight_number']) || !empty($tripData['airline']) || 
                        !empty($tripData['departure_airport_code']) || !empty($tripData['arrival_airport_code']);
    
    if ($isFlightTransport) {
        echo "AVION (Vol: {$tripData['flight_number']}, Compagnie: {$tripData['airline']})\n";
    } else {
        echo "TERRESTRE\n";
    }
    
    echo "- Date de départ: {$tripData['departure_date']}\n";
    echo "- Créé le: {$tripData['created_at']}\n";
    echo "- Mis à jour: {$tripData['updated_at']}\n\n";
    
    // Test manuel des règles de validation
    echo "=== Test des règles de validation ===\n";
    
    if ($isFlightTransport) {
        $isCanadaDeparture = $tripData['departure_country'] === 'Canada';
        $isCanadaArrival = $tripData['arrival_country'] === 'Canada';
        
        echo "- Transport aérien détecté\n";
        echo "- Départ Canada: " . ($isCanadaDeparture ? "✅" : "❌") . "\n";
        echo "- Arrivée Canada: " . ($isCanadaArrival ? "✅" : "❌") . "\n";
        
        if (!$isCanadaDeparture && !$isCanadaArrival) {
            echo "❌ ERREUR: Les voyages par avion doivent toujours inclure le Canada\n";
        } else {
            echo "✅ Règle de transport respectée\n";
        }
    } else {
        echo "- Transport terrestre détecté\n";
        if ($tripData['departure_country'] !== 'Canada' || $tripData['arrival_country'] !== 'Canada') {
            echo "❌ ERREUR: Les voyages par route sont limités aux villes canadiennes\n";
        } else {
            echo "✅ Règle de transport respectée\n";
        }
    }
    
    // Vérifier si la date de départ est dans le futur
    $departureTime = strtotime($tripData['departure_date']);
    $now = time();
    
    echo "- Date de départ: ";
    if ($departureTime > $now) {
        echo "✅ Dans le futur (" . round(($departureTime - $now) / 86400) . " jours)\n";
    } else {
        echo "❌ Dans le passé\n";
    }
    
    // Vérifier les champs requis
    echo "- Champs requis:\n";
    $requiredFields = ['departure_city', 'departure_country', 'arrival_city', 'arrival_country', 
                      'departure_date', 'arrival_date', 'available_weight_kg', 'price_per_kg'];
    
    foreach ($requiredFields as $field) {
        if (empty($tripData[$field]) && $tripData[$field] !== '0') {
            echo "  ❌ $field: manquant\n";
        } else {
            echo "  ✅ $field: {$tripData[$field]}\n";
        }
    }
    
    echo "\n=== Résumé ===\n";
    echo "Le voyage devrait " . ($isFlightTransport && 
                               ($tripData['departure_country'] === 'Canada' || $tripData['arrival_country'] === 'Canada') &&
                               $departureTime > $now ? "✅ POUVOIR" : "❌ NE PAS POUVOIR") . " être publié.\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}