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
    private ?Messaging $messaging;
    
    public function __construct()
    {
        $settings = require __DIR__ . '/../../config/settings.php';
        $firebaseConfig = $settings['firebase'] ?? [];
        
        try {
            $factory = new Factory();
            
            // Priorité 1: Utiliser le fichier JSON si disponible
            $serviceAccountPath = __DIR__ . '/../../config/firebase-service-account.json';
            if (file_exists($serviceAccountPath)) {
                error_log("Using Firebase service account from JSON file");
                $factory = $factory->withServiceAccount($serviceAccountPath);
                $this->messaging = $factory->createMessaging();
                error_log("Firebase initialized successfully from JSON file");
            }
            // Priorité 2: Configuration via les variables d'environnement
            elseif (!empty($firebaseConfig['private_key']) && !empty($firebaseConfig['client_email'])) {
                error_log("Using Firebase service account from environment variables");
                // Créer la configuration service account à partir des variables d'environnement
                $serviceAccountConfig = [
                    'type' => $firebaseConfig['type'],
                    'project_id' => $firebaseConfig['project_id'],
                    'private_key_id' => $firebaseConfig['private_key_id'],
                    'private_key' => $firebaseConfig['private_key'],
                    'client_email' => $firebaseConfig['client_email'],
                    'client_id' => $firebaseConfig['client_id'],
                    'auth_uri' => $firebaseConfig['auth_uri'],
                    'token_uri' => $firebaseConfig['token_uri'],
                    'auth_provider_x509_cert_url' => $firebaseConfig['auth_provider_x509_cert_url'],
                    'client_x509_cert_url' => $firebaseConfig['client_x509_cert_url'],
                    'universe_domain' => $firebaseConfig['universe_domain']
                ];
                
                $factory = $factory->withServiceAccount($serviceAccountConfig);
                $this->messaging = $factory->createMessaging();
                error_log("Firebase initialized successfully from environment variables");
            } else {
                error_log("Firebase credentials not configured, notifications will be disabled");
                $this->messaging = null;
                return; // Exit constructor without throwing error
            }
        } catch (Exception $e) {
            error_log("Firebase initialization error: " . $e->getMessage());
            $this->messaging = null;
            // Don't throw the exception, just disable notifications
            return;
        }
    }

    /**
     * Envoyer une notification à un utilisateur spécifique
     */
    public function sendToUser(int $userId, string $title, string $body, array $data = []): bool
    {
        // Vérifier si Firebase est initialisé
        if ($this->messaging === null) {
            error_log("Firebase not initialized, cannot send notification to user $userId");
            return false;
        }
        
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
        // Vérifier si Firebase est initialisé
        if ($this->messaging === null) {
            error_log("Firebase not initialized, cannot send notification to tokens");
            return false;
        }
        
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
     * Enregistrer un token FCM pour un utilisateur (optimisé anti-duplicata)
     */
    public function registerToken(int $userId, string $token, string $platform = 'mobile'): bool
    {
        try {
            // ✅ OPTIMISATION: Vérifier si le token existe déjà ET est actif
            $existingToken = UserFCMToken::where('user_id', $userId)
                                        ->where('fcm_token', $token)
                                        ->where('is_active', true)
                                        ->first();
            
            if ($existingToken) {
                // ✅ Token déjà enregistré et actif, pas besoin de refaire quoi que ce soit
                error_log("FCM Token already registered and active for user $userId: " . substr($token, 0, 20) . "...");
                return true;
            }
            
            // Vérifier s'il existe mais désactivé
            $inactiveToken = UserFCMToken::where('user_id', $userId)
                                        ->where('fcm_token', $token)
                                        ->where('is_active', false)
                                        ->first();
            
            if ($inactiveToken) {
                // Réactiver le token s'il était désactivé
                $inactiveToken->is_active = true;
                $inactiveToken->updated_at = date('Y-m-d H:i:s');
                error_log("FCM Token reactivated for user $userId: " . substr($token, 0, 20) . "...");
                return $inactiveToken->save();
            }
            
            // ✅ Désactiver les anciens tokens du même utilisateur sur la même plateforme
            UserFCMToken::where('user_id', $userId)
                       ->where('platform', $platform)
                       ->update(['is_active' => false]);
            
            // Créer un nouveau token (même si Firebase n'est pas initialisé)
            $newToken = UserFCMToken::create([
                'user_id' => $userId,
                'fcm_token' => $token,
                'platform' => $platform,
                'is_active' => true,
            ]);
            
            error_log("New FCM Token registered for user $userId: " . substr($token, 0, 20) . "...");
            return $newToken !== null;
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
     * Méthode simplifiée pour envoyer une notification à un token FCM
     */
    public function sendNotification(string $token, array $notification, array $data = []): array
    {
        try {
            if (empty($token)) {
                return [
                    'success' => false,
                    'error' => 'FCM token is required'
                ];
            }

            if (!$this->messaging) {
                error_log('Firebase messaging not initialized');
                return [
                    'success' => false,
                    'error' => 'Firebase messaging not available'
                ];
            }

            $message = [
                'token' => $token,
                'notification' => [
                    'title' => $notification['title'] ?? '',
                    'body' => $notification['body'] ?? ''
                ]
            ];

            if (!empty($data)) {
                $message['data'] = array_map('strval', $data);
            }

            $response = $this->messaging->send($message);
            
            return [
                'success' => true,
                'message_id' => $response,
                'token' => $token
            ];
            
        } catch (Exception $e) {
            error_log("FCM send error to token {$token}: " . $e->getMessage());
            
            return [
                'success' => false,
                'error' => $e->getMessage(),
                'token' => $token
            ];
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