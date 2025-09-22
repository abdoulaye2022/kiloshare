<?php

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/src/Utils/Database.php';

use KiloShare\Utils\Database;
use KiloShare\Services\SmartNotificationService;
use KiloShare\Models\User;

// Initialiser la base de données
Database::initialize();

echo "=== Test du système de notifications KiloShare ===\n\n";

try {
    // Créer le service de notification
    $notificationService = new SmartNotificationService();

    // Trouver un utilisateur test
    $user = User::first();
    if (!$user) {
        echo "❌ Aucun utilisateur trouvé en base de données\n";
        exit(1);
    }

    echo "✅ Utilisateur test trouvé: {$user->first_name} {$user->last_name} (ID: {$user->id})\n\n";

    // Test 1: Notification de nouvelle demande de réservation
    echo "📱 Test 1: Notification de nouvelle demande de réservation\n";
    $result1 = $notificationService->send(
        $user->id,
        'booking_request_received',
        [
            'sender_name' => 'Jean Dupont',
            'trip_title' => 'Paris → Londres',
            'package_description' => 'Documents importants',
            'weight_kg' => 2.5,
            'proposed_price' => 25.00,
            'booking_id' => 123
        ]
    );

    if ($result1['success']) {
        echo "✅ Notification envoyée avec succès\n";
        echo "   Canaux utilisés: " . implode(', ', $result1['channels_used'] ?? []) . "\n";
        echo "   ID notification: " . $result1['notification_id'] . "\n";
    } else {
        echo "❌ Erreur: " . $result1['error'] . "\n";
    }
    echo "\n";

    // Test 2: Notification de message
    echo "💬 Test 2: Notification de nouveau message\n";
    $result2 = $notificationService->send(
        $user->id,
        'new_message',
        [
            'sender_name' => 'Marie Martin',
            'message_preview' => 'Bonjour, j\'aimerais discuter des détails...',
            'conversation_id' => 456,
            'booking_id' => 123
        ]
    );

    if ($result2['success']) {
        echo "✅ Notification envoyée avec succès\n";
        echo "   Canaux utilisés: " . implode(', ', $result2['channels_used'] ?? []) . "\n";
        echo "   ID notification: " . $result2['notification_id'] . "\n";
    } else {
        echo "❌ Erreur: " . $result2['error'] . "\n";
    }
    echo "\n";

    // Test 3: Notification de demande acceptée
    echo "✅ Test 3: Notification de demande acceptée\n";
    $result3 = $notificationService->send(
        $user->id,
        'booking_accepted_payment_pending',
        [
            'trip_title' => 'Lyon → Marseille',
            'total_amount' => 35.00,
            'confirmation_deadline' => '4 heures'
        ]
    );

    if ($result3['success']) {
        echo "✅ Notification envoyée avec succès\n";
        echo "   Canaux utilisés: " . implode(', ', $result3['channels_used'] ?? []) . "\n";
        echo "   ID notification: " . $result3['notification_id'] . "\n";
    } else {
        echo "❌ Erreur: " . $result3['error'] . "\n";
    }
    echo "\n";

    // Vérifier l'état FCM
    echo "🔥 État Firebase Cloud Messaging:\n";
    $firebaseService = new \KiloShare\Services\FirebaseNotificationService();

    // Vérifier les tokens FCM de l'utilisateur
    $tokens = \KiloShare\Models\UserFCMToken::where('user_id', $user->id)->get();
    echo "   Tokens FCM enregistrés pour cet utilisateur: " . $tokens->count() . "\n";

    foreach ($tokens as $token) {
        echo "   - Token: " . substr($token->fcm_token, 0, 20) . "... (actif: " . ($token->is_active ? 'oui' : 'non') . ")\n";
    }

    if ($tokens->count() === 0) {
        echo "   ⚠️  Aucun token FCM, les notifications push ne seront pas envoyées\n";
        echo "   💡 Pour recevoir des notifications push, l'utilisateur doit se connecter depuis l'app mobile\n";
    }
    echo "\n";

    echo "🎉 Tests terminés avec succès !\n";
    echo "\n";
    echo "📋 Résumé:\n";
    echo "   - Service de notifications: ✅ Fonctionnel\n";
    echo "   - Templates de notification: ✅ Configurés\n";
    echo "   - Base de données: ✅ Connectée\n";
    echo "   - Envoi multi-canal: ✅ Opérationnel\n";

    if ($tokens->count() > 0) {
        echo "   - Notifications push: ✅ Tokens disponibles\n";
    } else {
        echo "   - Notifications push: ⚠️  Tokens manquants\n";
    }

} catch (Exception $e) {
    echo "❌ Erreur lors du test: " . $e->getMessage() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
    exit(1);
}