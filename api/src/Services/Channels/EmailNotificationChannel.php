<?php

declare(strict_types=1);

namespace KiloShare\Services\Channels;

use KiloShare\Models\User;
use KiloShare\Services\EmailService;
use Exception;

class EmailNotificationChannel implements NotificationChannelInterface
{
    private EmailService $emailService;

    public function __construct()
    {
        $this->emailService = new EmailService();
    }

    public function send(User $user, array $rendered, array $data = []): array
    {
        try {
            $to = $this->getRecipient($user);
            if (!$to) {
                return ['success' => false, 'error' => 'No email address available'];
            }

            $subject = $rendered['title'] ?? 'Notification KiloShare';
            $message = $rendered['message'] ?? '';
            $actionUrl = $data['action_url'] ?? null;
            $actionText = $data['action_text'] ?? 'Voir détails';

            $userName = $user->first_name ? "{$user->first_name} {$user->last_name}" : $user->email;

            $success = $this->emailService->sendNotificationEmail(
                $to,
                $userName,
                $subject,
                $message,
                $actionUrl,
                $actionText
            );

            return [
                'success' => $success,
                'provider' => 'brevo',
                'error' => $success ? null : 'Failed to send via Brevo'
            ];

        } catch (Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }


    public function getRecipient(User $user): ?string
    {
        return $user->email;
    }

    public function isAvailable(User $user): bool
    {
        return !empty($user->email) && filter_var($user->email, FILTER_VALIDATE_EMAIL);
    }

    public function getName(): string
    {
        return 'email';
    }

    public function getDisplayName(): string
    {
        return 'Email';
    }

    public function getCost(): int
    {
        return 1;
    }
}