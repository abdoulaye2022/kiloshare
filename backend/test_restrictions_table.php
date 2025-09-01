<?php
// Test simple pour vérifier la table trip_restrictions

echo "=== Test Table trip_restrictions ===\n\n";

try {
    $pdo = new PDO('mysql:host=localhost;dbname=kiloshare', 'root', '');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // 1. Vérifier si la table existe
    echo "1. Vérification de l'existence de la table trip_restrictions...\n";
    $stmt = $pdo->query("SHOW TABLES LIKE 'trip_restrictions'");
    $tableExists = $stmt->rowCount() > 0;
    
    if (!$tableExists) {
        echo "❌ La table trip_restrictions n'existe pas!\n";
        echo "Création de la table...\n";
        
        $createTable = "
        CREATE TABLE trip_restrictions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            trip_id INT NOT NULL,
            restricted_categories JSON,
            restricted_items JSON,
            restriction_notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
            INDEX idx_trip_id (trip_id)
        )";
        
        $pdo->exec($createTable);
        echo "✅ Table trip_restrictions créée!\n\n";
    } else {
        echo "✅ Table trip_restrictions existe\n\n";
    }
    
    // 2. Vérifier la structure de la table
    echo "2. Structure de la table trip_restrictions:\n";
    $stmt = $pdo->query("DESCRIBE trip_restrictions");
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['Field']}: {$row['Type']}\n";
    }
    echo "\n";
    
    // 3. Vérifier les données existantes
    echo "3. Données existantes dans trip_restrictions:\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM trip_restrictions");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "Nombre d'enregistrements: $count\n\n";
    
    if ($count > 0) {
        echo "Échantillon des données:\n";
        $stmt = $pdo->query("SELECT * FROM trip_restrictions LIMIT 5");
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "  Trip ID {$row['trip_id']}: categories = {$row['restricted_categories']}, items = {$row['restricted_items']}\n";
        }
    }
    
    // 4. Test de la requête JOIN utilisée dans TripService
    echo "\n4. Test de la requête JOIN pour trip ID 19:\n";
    $stmt = $pdo->prepare("
        SELECT t.id, t.status,
               tr.restricted_categories, tr.restricted_items, tr.restriction_notes
        FROM trips t
        LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
        WHERE t.id = ? AND t.deleted_at IS NULL
    ");
    $stmt->execute([19]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        echo "✅ Voyage trouvé:\n";
        echo "  - ID: {$result['id']}\n";
        echo "  - Status: {$result['status']}\n";
        echo "  - restricted_categories: " . ($result['restricted_categories'] ?? 'NULL') . "\n";
        echo "  - restricted_items: " . ($result['restricted_items'] ?? 'NULL') . "\n";
        echo "  - restriction_notes: " . ($result['restriction_notes'] ?? 'NULL') . "\n";
        
        if ($result['restricted_categories'] === null && $result['restricted_items'] === null) {
            echo "\n⚠️  PROBLÈME: Aucune restriction trouvée pour ce voyage.\n";
            echo "Cela explique pourquoi Flutter reçoit null.\n";
        }
    } else {
        echo "❌ Voyage ID 19 non trouvé!\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}

echo "\n=== Test terminé ===\n";