<?php

require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Services\SmartNotificationService;
use KiloShare\Models\UserNotificationPreferences;
use KiloShare\Models\User;

// Configuration de base  
$capsule = new \Illuminate\Database\Capsule\Manager;
$capsule->addConnection([
    'driver' => 'mysql',
    'host' => '127.0.0.1',
    'database' => 'kiloshare',
    'username' => 'root',
    'password' => '',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'prefix' => '',
]);
$capsule->setAsGlobal();
$capsule->bootEloquent();

echo "=== Test du Système de Notifications Intelligent ===\n\n";

try {
    // Test avec l'utilisateur ID 2
    $userId = 2;
    echo "Test avec l'utilisateur ID: $userId\n";
    
    // Vérifier si l'utilisateur existe
    $user = User::find($userId);
    if (!$user) {
        echo "Erreur: Utilisateur non trouvé\n";
        exit(1);
    }
    
    echo "Utilisateur trouvé: {$user->email}\n\n";
    
    // Obtenir ou créer les préférences
    $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
    if (!$preferences) {
        echo "Création des préférences par défaut...\n";
        $preferences = UserNotificationPreferences::createForUser($userId);
        echo "Préférences créées.\n";
    } else {
        echo "Préférences existantes trouvées.\n";
    }
    
    echo "\nPréférences actuelles:\n";
    echo "- Push enabled: " . ($preferences->push_enabled ? 'OUI' : 'NON') . "\n";
    echo "- Email enabled: " . ($preferences->email_enabled ? 'OUI' : 'NON') . "\n";
    echo "- Quiet hours: " . ($preferences->quiet_hours_enabled ? 'OUI' : 'NON') . "\n";
    echo "- Can receive now: " . ($preferences->canReceiveNotificationNow() ? 'OUI' : 'NON') . "\n";
    
    // Test du service de notifications
    echo "\n=== Test des Notifications ===\n";
    $notificationService = new SmartNotificationService();
    
    // Test 1: Demande de réservation
    echo "\n1. Test: Demande de réservation\n";
    $result1 = $notificationService->send($userId, 'booking_request', [
        'trip_id' => 123,
        'sender' => 'Jean Dupont'
    ]);
    echo "Résultat: " . json_encode($result1, JSON_PRETTY_PRINT) . "\n";
    
    // Test 2: Paiement reçu
    echo "\n2. Test: Paiement reçu\n";
    $result2 = $notificationService->send($userId, 'payment_received', [
        'amount' => 50.00,
        'currency' => 'EUR'
    ]);
    echo "Résultat: " . json_encode($result2, JSON_PRETTY_PRINT) . "\n";
    
    // Test 3: Avec préférences modifiées (push désactivé)
    echo "\n3. Test: Avec push désactivé\n";
    $preferences->update(['push_enabled' => false]);
    $result3 = $notificationService->send($userId, 'trip_cancelled', [
        'trip_id' => 456,
        'reason' => 'Imprévu'
    ]);
    echo "Résultat: " . json_encode($result3, JSON_PRETTY_PRINT) . "\n";
    
    // Restaurer les préférences
    $preferences->update(['push_enabled' => true]);
    
    // Test 4: Notification critique (devrait passer même en heures calmes)
    echo "\n4. Test: Notification critique\n";
    $result4 = $notificationService->send($userId, 'account_suspended', [
        'reason' => 'Activité suspecte'
    ]);
    echo "Résultat: " . json_encode($result4, JSON_PRETTY_PRINT) . "\n";
    
    echo "\n=== Tous les tests terminés ===\n";
    
} catch (Exception $e) {
    echo "Erreur: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}