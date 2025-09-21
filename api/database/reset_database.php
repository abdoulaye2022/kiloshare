<?php

/**
 * Script pour vider la base de données KiloShare
 * ATTENTION: À utiliser uniquement en développement !
 */

require_once __DIR__ . '/../vendor/autoload.php';

// Configuration de la base de données
$host = $_ENV['DB_HOST'] ?? 'localhost';
$dbname = $_ENV['DB_NAME'] ?? 'kiloshare';
$username = $_ENV['DB_USER'] ?? 'root';
$password = $_ENV['DB_PASS'] ?? '';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    echo "🔗 Connexion à la base de données réussie\n";

    // Désactiver les contraintes de clés étrangères
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 0");
    echo "⚠️  Contraintes de clés étrangères désactivées\n";

    // Tables à vider (préserver users et tables de config)
    $tablesToTruncate = [
        // Données principales
        'bookings',
        'trips',
        'messages',
        'reviews',
        'favorites',
        'trip_photos',
        'package_photos',

        // Paiements
        'payments',
        'transactions',
        'payment_authorizations',
        'payment_events_log',

        // Livraison
        'delivery_codes',
        'delivery_code_attempts',
        'delivery_code_history',

        // Jobs/Tâches
        'scheduled_jobs',

        // Notifications
        'notifications',
        'fcm_tokens',

        // Auth/Session (sauf users)
        'password_resets',
        'verification_codes',

        // Logs
        'activity_logs',
        'error_logs'
    ];

    // Tables préservées (ne pas truncate)
    $preservedTables = [
        'users',                    // Données utilisateur
        'notification_templates',   // Templates par défaut
        'payment_configuration',    // Configuration paiement
        'migrations',              // Historique migrations
        'settings'                 // Configuration système
    ];

    echo "\n📋 Tables à vider :\n";
    foreach ($tablesToTruncate as $table) {
        echo "   - $table\n";
    }

    echo "\n🔒 Tables préservées :\n";
    foreach ($preservedTables as $table) {
        echo "   - $table\n";
    }

    echo "\n";

    // Confirmation en mode interactif
    if (php_sapi_name() === 'cli') {
        echo "⚠️  ATTENTION: Cette opération va vider toutes les données sauf users et configuration.\n";
        echo "Voulez-vous continuer ? (oui/non): ";
        $handle = fopen("php://stdin", "r");
        $confirmation = trim(fgets($handle));
        fclose($handle);

        if (strtolower($confirmation) !== 'oui') {
            echo "❌ Opération annulée\n";
            exit(0);
        }
    }

    // Exécuter le truncate
    $truncatedCount = 0;
    $errors = [];

    foreach ($tablesToTruncate as $table) {
        try {
            // Vérifier si la table existe
            $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
            $stmt->execute([$table]);

            if ($stmt->rowCount() > 0) {
                $pdo->exec("TRUNCATE TABLE `$table`");
                echo "✅ $table vidée\n";
                $truncatedCount++;
            } else {
                echo "⚠️  $table n'existe pas\n";
            }
        } catch (Exception $e) {
            $error = "❌ Erreur avec $table: " . $e->getMessage();
            echo "$error\n";
            $errors[] = $error;
        }
    }

    // Réactiver les contraintes de clés étrangères
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 1");
    echo "\n✅ Contraintes de clés étrangères réactivées\n";

    // Résumé
    echo "\n" . str_repeat("=", 50) . "\n";
    echo "📊 RÉSUMÉ :\n";
    echo "   • Tables vidées: $truncatedCount\n";
    echo "   • Erreurs: " . count($errors) . "\n";

    if (!empty($errors)) {
        echo "\n❌ ERREURS :\n";
        foreach ($errors as $error) {
            echo "   $error\n";
        }
    }

    // Vérifier les utilisateurs préservés
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM users");
    $userCount = $stmt->fetch()['count'];
    echo "   • Utilisateurs préservés: $userCount\n";

    // Vérifier la configuration de paiement
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM payment_configuration");
    $configCount = $stmt->fetch()['count'];
    echo "   • Configurations de paiement: $configCount\n";

    echo "\n🎉 Base de données réinitialisée avec succès !\n";

} catch (Exception $e) {
    echo "❌ ERREUR: " . $e->getMessage() . "\n";
    exit(1);
}