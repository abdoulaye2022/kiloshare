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

            $userName = $user->first_name ? "{$user->first_name} {$user->last_name}" : $user->email;
            $notificationType = $data['notification_type'] ?? null;

            // Utiliser un template spécialisé pour les demandes de réservation
            if ($notificationType === 'new_booking_request') {
                $bookingData = [
                    'sender_name' => $data['sender_name'] ?? 'Expéditeur',
                    'weight' => $data['weight'] ?? 0,
                    'price' => $data['price'] ?? 0,
                    'package_description' => $data['package_description'] ?? '',
                    'booking_reference' => $data['booking_reference'] ?? '',
                    'trip_route' => $data['trip_route'] ?? '',
                    'action_url' => $data['action_url'] ?? null,
                ];

                $success = $this->emailService->sendBookingRequestEmail(
                    $to,
                    $userName,
                    $bookingData
                );
            } elseif ($notificationType === 'delivery_confirmed') {
                // Template spécialisé pour la livraison confirmée
                $deliveryData = [
                    'package_description' => $data['package_description'] ?? '',
                    'booking_reference' => $data['booking_reference'] ?? '',
                    'trip_route' => $data['trip_route'] ?? '',
                    'confirmed_at' => $data['confirmed_at'] ?? date('d/m/Y à H:i'),
                    'is_receiver' => $data['is_receiver'] ?? false,
                    'sender_name' => $data['sender_name'] ?? '',
                    'receiver_name' => $data['receiver_name'] ?? '',
                    'action_url' => $data['action_url'] ?? null,
                ];

                $success = $this->emailService->sendDeliveryConfirmedEmail(
                    $to,
                    $userName,
                    $deliveryData
                );
            } elseif ($notificationType === 'booking_accepted') {
                // Template spécialisé pour la réservation acceptée
                $bookingData = [
                    'transporter_name' => $data['transporter_name'] ?? 'Le transporteur',
                    'trip_title' => $data['trip_title'] ?? 'Votre voyage',
                    'total_amount' => $data['total_amount'] ?? 0,
                    'package_description' => $data['package_description'] ?? '',
                    'weight_kg' => $data['weight_kg'] ?? 0,
                    'booking_reference' => $data['booking_reference'] ?? '',
                    'action_url' => $data['action_url'] ?? null,
                ];

                $success = $this->emailService->sendBookingAcceptedEmail(
                    $to,
                    $userName,
                    $bookingData
                );
            } else {
                // Email de notification générique
                $subject = $rendered['title'] ?? 'Notification KiloShare';
                $message = $rendered['message'] ?? '';
                $actionUrl = $data['action_url'] ?? null;
                $actionText = $data['action_text'] ?? 'Voir détails';

                $success = $this->emailService->sendNotificationEmail(
                    $to,
                    $userName,
                    $subject,
                    $message,
                    $actionUrl,
                    $actionText
                );
            }

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