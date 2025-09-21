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
            $fcmToken = $this->getRecipient($user);
            if (!$fcmToken) {
                return ['success' => false, 'error' => 'No FCM token available'];
            }

            $notification = [
                'title' => $rendered['title'] ?? '',
                'body' => $rendered['message'] ?? '',
            ];

            $pushData = array_merge($data, [
                'click_action' => $data['click_action'] ?? 'FLUTTER_NOTIFICATION_CLICK',
                'sound' => $data['sound'] ?? 'default',
            ]);

            $result = $this->firebaseService->sendNotification($fcmToken, $notification, $pushData);

            if ($result['success']) {
                return [
                    'success' => true,
                    'provider' => 'firebase',
                    'provider_message_id' => $result['message_id'] ?? null,
                ];
            } else {
                return [
                    'success' => false,
                    'error' => $result['error'] ?? 'Push notification failed',
                ];
            }

        } catch (Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    public function getRecipient(User $user): ?string
    {
        return $user->fcm_token;
    }

    public function isAvailable(User $user): bool
    {
        return !empty($user->fcm_token);
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