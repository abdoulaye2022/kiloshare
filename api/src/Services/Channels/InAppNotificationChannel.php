<?php

declare(strict_types=1);

namespace KiloShare\Services\Channels;

use KiloShare\Models\User;
use KiloShare\Models\Notification;
use Exception;

class InAppNotificationChannel implements NotificationChannelInterface
{
    public function send(User $user, array $rendered, array $data = []): array
    {
        try {
            $notification = new Notification();
            
            $result = $notification->create([
                'user_id' => $user->id,
                'title' => $rendered['title'] ?? 'Notification',
                'message' => $rendered['message'] ?? '',
                'type' => $data['type'] ?? 'general',
                'scope' => $data['scope'] ?? 'user',
                'scope_id' => $data['scope_id'] ?? null,
                'priority' => $data['priority'] ?? 'normal',
                'channel' => 'in_app',
                'data' => json_encode($data),
                'action_url' => $data['action_url'] ?? null,
                'action_text' => $data['action_text'] ?? null,
                'expires_at' => $data['expires_at'] ?? null,
                'is_read' => false,
                'created_at' => date('Y-m-d H:i:s'),
            ]);

            if ($result) {
                return [
                    'success' => true,
                    'provider' => 'in_app',
                    'provider_message_id' => $result,
                ];
            } else {
                return ['success' => false, 'error' => 'Failed to create in-app notification'];
            }

        } catch (Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    public function getRecipient(User $user): ?string
    {
        return (string)$user->id;
    }

    public function isAvailable(User $user): bool
    {
        return !empty($user->id);
    }

    public function getName(): string
    {
        return 'in_app';
    }

    public function getDisplayName(): string
    {
        return 'In-App Notification';
    }

    public function getCost(): int
    {
        return 0;
    }
}