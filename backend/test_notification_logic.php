<?php

require_once __DIR__ . '/vendor/autoload.php';

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

echo "=== Test de la Logique de Notifications (sans Firebase) ===\n\n";

try {
    $userId = 2;
    echo "Test avec l'utilisateur ID: $userId\n";
    
    // Obtenir l'utilisateur
    $user = User::find($userId);
    echo "Utilisateur: {$user->email}\n";
    
    // Obtenir les préférences
    $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
    if (!$preferences) {
        echo "Création des préférences par défaut...\n";
        $preferences = UserNotificationPreferences::createForUser($userId);
    }
    
    echo "\n=== État des Préférences ===\n";
    echo "Push enabled: " . ($preferences->push_enabled ? 'OUI' : 'NON') . "\n";
    echo "Email enabled: " . ($preferences->email_enabled ? 'OUI' : 'NON') . "\n";
    echo "SMS enabled: " . ($preferences->sms_enabled ? 'OUI' : 'NON') . "\n";
    echo "In-app enabled: " . ($preferences->in_app_enabled ? 'OUI' : 'NON') . "\n";
    echo "Marketing enabled: " . ($preferences->marketing_enabled ? 'OUI' : 'NON') . "\n";
    echo "\nHeures calmes: " . ($preferences->quiet_hours_enabled ? 'OUI' : 'NON') . "\n";
    echo "Début: {$preferences->quiet_hours_start}\n";
    echo "Fin: {$preferences->quiet_hours_end}\n";
    echo "Timezone: {$preferences->timezone}\n";
    echo "Peut recevoir maintenant: " . ($preferences->canReceiveNotificationNow() ? 'OUI' : 'NON') . "\n";
    
    echo "\n=== Préférences par Catégorie ===\n";
    echo "Trip updates - Push: " . ($preferences->trip_updates_push ? 'OUI' : 'NON') . "\n";
    echo "Trip updates - Email: " . ($preferences->trip_updates_email ? 'OUI' : 'NON') . "\n";
    echo "Booking updates - Push: " . ($preferences->booking_updates_push ? 'OUI' : 'NON') . "\n";
    echo "Booking updates - Email: " . ($preferences->booking_updates_email ? 'OUI' : 'NON') . "\n";
    echo "Payment updates - Push: " . ($preferences->payment_updates_push ? 'OUI' : 'NON') . "\n";
    echo "Payment updates - Email: " . ($preferences->payment_updates_email ? 'OUI' : 'NON') . "\n";
    echo "Security alerts - Push: " . ($preferences->security_alerts_push ? 'OUI' : 'NON') . "\n";
    echo "Security alerts - Email: " . ($preferences->security_alerts_email ? 'OUI' : 'NON') . "\n";
    
    // Tester les différentes logiques
    echo "\n=== Test Logique de Détermination des Canaux ===\n";
    
    // Simuler la logique du SmartNotificationService
    function determineChannels($notificationType, $preferences) {
        $channels = [];
        
        // Mapping des types vers les catégories
        $typeMapping = [
            'booking_request' => 'booking_updates',
            'booking_accepted' => 'booking_updates',
            'payment_received' => 'payment_updates',
            'trip_cancelled' => 'trip_updates',
            'login_from_new_device' => 'security_alerts',
        ];
        
        $categoryField = $typeMapping[$notificationType] ?? null;
        
        // Vérifier chaque canal
        if ($preferences->push_enabled && $categoryField) {
            $pushField = "{$categoryField}_push";
            if ($preferences->$pushField) {
                $channels[] = 'push';
            }
        }
        
        if ($preferences->email_enabled && $categoryField) {
            $emailField = "{$categoryField}_email";
            if ($preferences->$emailField) {
                $channels[] = 'email';
            }
        }
        
        if ($preferences->in_app_enabled) {
            $channels[] = 'in_app';
        }
        
        return $channels;
    }
    
    $testTypes = [
        'booking_request' => 'Demande de réservation',
        'payment_received' => 'Paiement reçu',
        'trip_cancelled' => 'Voyage annulé',
        'login_from_new_device' => 'Connexion nouveau device'
    ];
    
    foreach ($testTypes as $type => $description) {
        $channels = determineChannels($type, $preferences);
        echo "Type '$description' ($type): " . implode(', ', $channels) . "\n";
    }
    
    // Test modification des préférences
    echo "\n=== Test avec Push Désactivé ===\n";
    $originalPush = $preferences->push_enabled;
    $preferences->update(['push_enabled' => false]);
    
    foreach ($testTypes as $type => $description) {
        $channels = determineChannels($type, $preferences);
        echo "Type '$description' ($type): " . implode(', ', $channels) . "\n";
    }
    
    // Restaurer
    $preferences->update(['push_enabled' => $originalPush]);
    
    // Test heures calmes
    echo "\n=== Test Heures Calmes ===\n";
    $now = new DateTime();
    $currentHour = (int)$now->format('H');
    
    echo "Heure actuelle: " . $now->format('H:i:s') . "\n";
    echo "Heures calmes: {$preferences->quiet_hours_start} - {$preferences->quiet_hours_end}\n";
    echo "En heures calmes: " . (!$preferences->canReceiveNotificationNow() ? 'OUI' : 'NON') . "\n";
    
    // Simuler différentes heures
    $testHours = ['08:00:00', '12:00:00', '18:00:00', '22:30:00', '02:00:00'];
    foreach ($testHours as $testTime) {
        // Temporairement changer l'heure pour le test (simulation)
        echo "Si il était $testTime: ";
        
        $parts = explode(':', $testTime);
        $testHour = (int)$parts[0];
        $quietStart = (int)explode(':', $preferences->quiet_hours_start)[0];
        $quietEnd = (int)explode(':', $preferences->quiet_hours_end)[0];
        
        // Logique simplifiée (heures calmes traversent minuit)
        if ($quietStart > $quietEnd) {
            $inQuietHours = ($testHour >= $quietStart || $testHour <= $quietEnd);
        } else {
            $inQuietHours = ($testHour >= $quietStart && $testHour <= $quietEnd);
        }
        
        echo ($inQuietHours ? "EN heures calmes" : "HORS heures calmes") . "\n";
    }
    
    echo "\n=== Test réussi! ===\n";
    
} catch (Exception $e) {
    echo "Erreur: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}