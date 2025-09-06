<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Messaging;
use KiloShare\Models\User;
use KiloShare\Models\UserFCMToken;
use Exception;

class FirebaseNotificationService
{
    private Messaging $messaging;
    
    public function __construct()
    {
        $settings = require __DIR__ . '/../../config/settings.php';
        $firebaseConfig = $settings['firebase'] ?? [];
        
        try {
            $factory = new Factory();
            
            // Si on a un chemin vers le service account key file
            $credentialsPath = __DIR__ . '/../../' . $firebaseConfig['credentials_path'];
            if (!empty($firebaseConfig['credentials_path']) && file_exists($credentialsPath)) {
                $factory = $factory->withServiceAccount($credentialsPath);
            } else {
                // Configuration via project ID seulement
                $factory = $factory->withProjectId($firebaseConfig['project_id'] ?? 'kiloshare-8f7fa');
            }
            
            $this->messaging = $factory->createMessaging();
        } catch (Exception $e) {
            error_log("Firebase initialization error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Envoyer une notification à un utilisateur spécifique
     */
    public function sendToUser(int $userId, string $title, string $body, array $data = []): bool
    {
        try {
            // Récupérer tous les tokens FCM de l'utilisateur
            $tokens = UserFCMToken::where('user_id', $userId)
                                 ->where('is_active', true)
                                 ->pluck('fcm_token')
                                 ->toArray();
            
            if (empty($tokens)) {
                error_log("No FCM tokens found for user $userId");
                return false;
            }
            
            return $this->sendToTokens($tokens, $title, $body, $data);
        } catch (Exception $e) {
            error_log("Error sending notification to user $userId: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification à plusieurs tokens
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): bool
    {
        try {
            if (empty($tokens)) {
                return false;
            }
            
            $notification = Notification::create($title, $body);
            
            // Préparer les données
            $messageData = array_merge($data, [
                'title' => $title,
                'body' => $body,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                'sound' => 'default',
            ]);
            
            $message = CloudMessage::new()
                ->withNotification($notification)
                ->withData($messageData);
            
            // Envoyer à tous les tokens
            $report = $this->messaging->sendMulticast($message, $tokens);
            
            // Gérer les tokens invalides
            $this->handleFailedTokens($report, $tokens);
            
            $successCount = $report->successes()->count();
            $totalCount = count($tokens);
            
            error_log("Notification sent: $successCount/$totalCount successful");
            
            return $successCount > 0;
        } catch (Exception $e) {
            error_log("Error sending notification: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification à un topic
     */
    public function sendToTopic(string $topic, string $title, string $body, array $data = []): bool
    {
        try {
            $notification = Notification::create($title, $body);
            
            $messageData = array_merge($data, [
                'title' => $title,
                'body' => $body,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                'sound' => 'default',
            ]);
            
            $message = CloudMessage::withTarget('topic', $topic)
                ->withNotification($notification)
                ->withData($messageData);
            
            $this->messaging->send($message);
            
            return true;
        } catch (Exception $e) {
            error_log("Error sending topic notification: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Enregistrer un token FCM pour un utilisateur
     */
    public function registerToken(int $userId, string $token, string $platform = 'mobile'): bool
    {
        try {
            // Vérifier si le token existe déjà
            $existingToken = UserFCMToken::where('user_id', $userId)
                                        ->where('fcm_token', $token)
                                        ->first();
            
            if ($existingToken) {
                // Réactiver le token s'il était désactivé
                $existingToken->is_active = true;
                $existingToken->updated_at = date('Y-m-d H:i:s');
                return $existingToken->save();
            }
            
            // Créer un nouveau token
            return UserFCMToken::create([
                'user_id' => $userId,
                'fcm_token' => $token,
                'platform' => $platform,
                'is_active' => true,
            ]) !== null;
        } catch (Exception $e) {
            error_log("Error registering FCM token: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Désactiver un token FCM
     */
    public function unregisterToken(string $token): bool
    {
        try {
            return UserFCMToken::where('fcm_token', $token)
                              ->update(['is_active' => false]) > 0;
        } catch (Exception $e) {
            error_log("Error unregistering FCM token: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Désactiver tous les tokens d'un utilisateur
     */
    public function unregisterUserTokens(int $userId): bool
    {
        try {
            return UserFCMToken::where('user_id', $userId)
                              ->update(['is_active' => false]) >= 0;
        } catch (Exception $e) {
            error_log("Error unregistering user tokens: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification de test
     */
    public function sendTestNotification(int $userId): bool
    {
        return $this->sendToUser(
            $userId,
            '🧪 Test KiloShare',
            'Cette notification confirme que votre système de notifications fonctionne correctement !',
            [
                'type' => 'test',
                'action_url' => '/notifications',
                'priority' => 'high',
            ]
        );
    }

    /**
     * Envoyer des notifications liées aux voyages
     */
    public function sendTripNotification(int $userId, string $type, int $tripId, array $additionalData = []): bool
    {
        $notifications = [
            'trip_booked' => [
                'title' => '🎉 Réservation confirmée',
                'body' => 'Votre voyage a été réservé avec succès !',
            ],
            'trip_cancelled' => [
                'title' => '❌ Voyage annulé',
                'body' => 'Un voyage a été annulé. Consultez les détails.',
            ],
            'trip_reminder' => [
                'title' => '⏰ Rappel de voyage',
                'body' => 'N\'oubliez pas votre voyage qui approche !',
            ],
            'booking_request' => [
                'title' => '📝 Nouvelle demande de réservation',
                'body' => 'Quelqu\'un souhaite réserver votre voyage.',
            ],
            'payment_received' => [
                'title' => '💰 Paiement reçu',
                'body' => 'Vous avez reçu un paiement pour votre voyage.',
            ],
        ];
        
        if (!isset($notifications[$type])) {
            error_log("Unknown trip notification type: $type");
            return false;
        }
        
        $notification = $notifications[$type];
        $data = array_merge([
            'type' => $type,
            'trip_id' => (string)$tripId,
            'action_url' => "/trips/$tripId",
            'priority' => in_array($type, ['booking_request', 'payment_received']) ? 'high' : 'normal',
        ], $additionalData);
        
        return $this->sendToUser($userId, $notification['title'], $notification['body'], $data);
    }

    /**
     * Gérer les tokens qui ont échoué
     */
    private function handleFailedTokens($report, array $tokens): void
    {
        try {
            $failedTokens = [];
            
            foreach ($report->failures() as $failure) {
                $index = $failure->target()->position();
                if (isset($tokens[$index])) {
                    $failedToken = $tokens[$index];
                    $error = $failure->error();
                    
                    error_log("Failed token: $failedToken, Error: " . $error->getMessage());
                    
                    // Désactiver les tokens invalides
                    if ($error->getCode() === 'invalid-registration-token' || 
                        $error->getCode() === 'registration-token-not-registered') {
                        $failedTokens[] = $failedToken;
                    }
                }
            }
            
            // Désactiver les tokens invalides en batch
            if (!empty($failedTokens)) {
                UserFCMToken::whereIn('fcm_token', $failedTokens)
                           ->update(['is_active' => false]);
                
                error_log("Disabled " . count($failedTokens) . " invalid FCM tokens");
            }
        } catch (Exception $e) {
            error_log("Error handling failed tokens: " . $e->getMessage());
        }
    }

    /**
     * Obtenir les statistiques des tokens
     */
    public function getTokenStats(): array
    {
        try {
            $totalTokens = UserFCMToken::count();
            $activeTokens = UserFCMToken::where('is_active', true)->count();
            $inactiveTokens = UserFCMToken::where('is_active', false)->count();
            $uniqueUsers = UserFCMToken::where('is_active', true)->distinct('user_id')->count();
            
            return [
                'total_tokens' => $totalTokens,
                'active_tokens' => $activeTokens,
                'inactive_tokens' => $inactiveTokens,
                'unique_users' => $uniqueUsers,
            ];
        } catch (Exception $e) {
            error_log("Error getting token stats: " . $e->getMessage());
            return [];
        }
    }
}