<?php

declare(strict_types=1);

namespace KiloShare\Services\Channels;

use KiloShare\Models\User;
use KiloShare\Services\FirebaseNotificationService;
use Exception;

class PushNotificationChannel implements NotificationChannelInterface
{
    private FirebaseNotificationService $firebaseService;

    public function __construct()
    {
        $this->firebaseService = new FirebaseNotificationService();
    }

    public function send(User $user, array $rendered, array $data = []): array
    {
        try {
            // Récupérer tous les tokens FCM actifs de l'utilisateur depuis la table user_fcm_tokens
            $fcmTokens = \KiloShare\Models\UserFCMToken::where('user_id', $user->id)
                ->where('is_active', true)
                ->pluck('fcm_token')
                ->toArray();

            if (empty($fcmTokens)) {
                error_log("No FCM tokens found for user {$user->id}");
                return ['success' => false, 'error' => 'No FCM token available'];
            }

            error_log("Found " . count($fcmTokens) . " FCM token(s) for user {$user->id}");

            $notification = [
                'title' => $rendered['title'] ?? '',
                'body' => $rendered['message'] ?? $rendered['body'] ?? $rendered['content'] ?? '',
            ];

            $pushData = array_merge($data, [
                'click_action' => $data['click_action'] ?? 'FLUTTER_NOTIFICATION_CLICK',
                'sound' => $data['sound'] ?? 'default',
            ]);

            // Envoyer à tous les tokens actifs de l'utilisateur
            $successCount = 0;
            $lastError = null;

            foreach ($fcmTokens as $fcmToken) {
                error_log("Sending FCM to token: " . substr($fcmToken, 0, 20) . "...");
                $result = $this->firebaseService->sendNotification($fcmToken, $notification, $pushData);

                if ($result['success']) {
                    $successCount++;
                    error_log("FCM sent successfully to token: " . substr($fcmToken, 0, 20) . "...");
                } else {
                    $lastError = $result['error'] ?? 'Push notification failed';
                    error_log("FCM failed for token: " . substr($fcmToken, 0, 20) . "... Error: " . $lastError);
                }
            }

            if ($successCount > 0) {
                return [
                    'success' => true,
                    'provider' => 'firebase',
                    'tokens_sent' => $successCount,
                    'total_tokens' => count($fcmTokens),
                ];
            } else {
                return [
                    'success' => false,
                    'error' => $lastError ?? 'All push notifications failed',
                ];
            }

        } catch (Exception $e) {
            error_log("PushNotificationChannel exception: " . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    public function getRecipient(User $user): ?string
    {
        // Pour compatibilité avec l'interface - retourne le premier token
        $tokens = \KiloShare\Models\UserFCMToken::where('user_id', $user->id)
            ->where('is_active', true)
            ->pluck('fcm_token')
            ->toArray();

        return !empty($tokens) ? $tokens[0] : null;
    }

    public function isAvailable(User $user): bool
    {
        $token = $this->getRecipient($user);
        return !empty($token);
    }

    public function getName(): string
    {
        return 'push';
    }

    public function getDisplayName(): string
    {
        return 'Push Notification';
    }

    public function getCost(): int
    {
        return 0;
    }
}