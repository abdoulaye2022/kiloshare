<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\UserNotificationPreferences;
use KiloShare\Models\User;
use KiloShare\Models\Notification;
use KiloShare\Models\NotificationLog;
use KiloShare\Services\Channels\PushNotificationChannel;
use KiloShare\Services\Channels\EmailNotificationChannel;
use KiloShare\Services\Channels\SmsNotificationChannel;
use KiloShare\Services\Channels\InAppNotificationChannel;
use Exception;
use DateTime;
use DateTimeZone;

/**
 * Service intelligent de notifications basé sur les préférences utilisateur
 */
class SmartNotificationService
{
    private array $channels = [];

    public function __construct()
    {
        $this->channels = [
            'push' => new PushNotificationChannel(),
            'email' => new EmailNotificationChannel(),
            'sms' => new SmsNotificationChannel(),
            'in_app' => new InAppNotificationChannel(),
        ];
    }

    /**
     * Envoyer une notification intelligente basée sur les préférences
     */
    public function send(
        int $userId,
        string $notificationType,
        array $data = [],
        array $options = []
    ): array {
        try {
            $user = User::find($userId);
            if (!$user) {
                throw new Exception("User not found: {$userId}");
            }

            // Obtenir les préférences utilisateur
            $preferences = $this->getUserPreferences($userId);
            if (!$preferences) {
                return ['success' => false, 'error' => 'No preferences found'];
            }

            // Déterminer les canaux autorisés
            $allowedChannels = $this->determineAllowedChannels($notificationType, $preferences, $options);
            
            if (empty($allowedChannels)) {
                return ['success' => false, 'error' => 'No channels allowed by user preferences'];
            }

            // Vérifier les heures calmes (sauf pour les notifications critiques)
            if (!$this->isCriticalNotification($notificationType) && !$preferences->canReceiveNotificationNow()) {
                // En heures calmes, ne garder que l'email et in-app
                $allowedChannels = array_intersect($allowedChannels, ['email', 'in_app']);
            }

            if (empty($allowedChannels)) {
                return ['success' => false, 'error' => 'Blocked by quiet hours'];
            }

            // Créer la notification in-app (toujours créée pour l'historique)
            $notification = $this->createInAppNotification($userId, $notificationType, $data);

            // Envoyer via chaque canal autorisé
            $results = [];
            foreach ($allowedChannels as $channel) {
                $results[$channel] = $this->sendViaChannel($user, $channel, $notificationType, $data, $preferences);
            }

            return [
                'success' => true,
                'notification_id' => $notification->id,
                'channels_used' => $allowedChannels,
                'results' => $results
            ];

        } catch (Exception $e) {
            error_log("SmartNotificationService error: " . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Obtenir les préférences utilisateur
     */
    private function getUserPreferences(int $userId): ?UserNotificationPreferences
    {
        return UserNotificationPreferences::where('user_id', $userId)->first();
    }

    /**
     * Déterminer les canaux autorisés pour un type de notification
     */
    private function determineAllowedChannels(
        string $notificationType,
        UserNotificationPreferences $preferences,
        array $options
    ): array {
        $channels = [];

        // Mapping des types de notifications vers les champs de la table
        $typeMapping = [
            // Notifications de trajets
            'trip_created' => 'trip_updates',
            'trip_updated' => 'trip_updates', 
            'trip_cancelled' => 'trip_updates',
            'trip_reminder' => 'trip_updates',
            
            // Notifications de réservations
            'booking_request' => 'booking_updates',
            'booking_accepted' => 'booking_updates',
            'booking_rejected' => 'booking_updates',
            'booking_cancelled' => 'booking_updates',
            'booking_confirmed' => 'booking_updates',
            
            // Notifications de paiements
            'payment_received' => 'payment_updates',
            'payment_failed' => 'payment_updates',
            'payment_refunded' => 'payment_updates',
            'payout_processed' => 'payment_updates',
            
            // Alertes de sécurité
            'login_from_new_device' => 'security_alerts',
            'password_changed' => 'security_alerts',
            'account_suspended' => 'security_alerts',
            'suspicious_activity' => 'security_alerts',
        ];

        $categoryField = $typeMapping[$notificationType] ?? null;
        
        // Vérifier chaque canal
        if ($preferences->push_enabled && $this->isChannelAllowedForType($categoryField, 'push', $preferences)) {
            $channels[] = 'push';
        }
        
        if ($preferences->email_enabled && $this->isChannelAllowedForType($categoryField, 'email', $preferences)) {
            $channels[] = 'email';
        }
        
        if ($preferences->sms_enabled && $this->isChannelAllowedForType($categoryField, 'sms', $preferences)) {
            // SMS uniquement pour certains types critiques
            if ($this->isSmsNotificationType($notificationType)) {
                $channels[] = 'sms';
            }
        }
        
        if ($preferences->in_app_enabled) {
            $channels[] = 'in_app';
        }

        // Filtrer selon les options si spécifiées
        if (isset($options['channels'])) {
            $channels = array_intersect($channels, $options['channels']);
        }

        return $channels;
    }

    /**
     * Vérifier si un canal est autorisé pour un type de notification
     */
    private function isChannelAllowedForType(?string $categoryField, string $channel, UserNotificationPreferences $preferences): bool
    {
        if (!$categoryField) {
            return true; // Par défaut, autorisé si pas de catégorie spécifique
        }

        $fieldName = "{$categoryField}_{$channel}";
        return $preferences->getAttribute($fieldName) ?? true;
    }

    /**
     * Vérifier si c'est un type de notification critique
     */
    private function isCriticalNotification(string $type): bool
    {
        $criticalTypes = [
            'account_suspended',
            'security_alert', 
            'payment_failed',
            'booking_cancelled', // Important pour les voyageurs
            'trip_cancelled'     // Important pour les expéditeurs
        ];
        
        return in_array($type, $criticalTypes);
    }

    /**
     * Vérifier si c'est un type de notification SMS
     */
    private function isSmsNotificationType(string $type): bool
    {
        $smsTypes = [
            'pickup_code',
            'delivery_code', 
            'verification_code',
            'security_alert'
        ];
        
        return in_array($type, $smsTypes);
    }

    /**
     * Créer une notification in-app
     */
    private function createInAppNotification(int $userId, string $type, array $data): Notification
    {
        return Notification::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $this->getNotificationTitle($type),
            'message' => $this->getNotificationMessage($type, $data),
            'data' => json_encode($data),
            'read_at' => null,
            'created_at' => now()
        ]);
    }

    /**
     * Envoyer via un canal spécifique
     */
    private function sendViaChannel(
        User $user,
        string $channel,
        string $type,
        array $data,
        UserNotificationPreferences $preferences
    ): array {
        try {
            if (!isset($this->channels[$channel])) {
                return ['success' => false, 'error' => "Channel not available: {$channel}"];
            }

            $channelService = $this->channels[$channel];
            
            // Préparer le message selon le canal
            $message = $this->prepareMessage($type, $data, $channel, $preferences);
            
            // Créer le log
            $log = NotificationLog::create([
                'user_id' => $user->id,
                'channel' => $channel,
                'type' => $type,
                'recipient' => $this->getRecipientForChannel($user, $channel),
                'message' => $message['content'] ?? '',
                'status' => 'pending',
                'created_at' => now()
            ]);

            // Envoyer
            $result = $channelService->send($user, $message, $data);
            
            // Mettre à jour le log
            $log->update([
                'status' => $result['success'] ? 'sent' : 'failed',
                'error_message' => $result['error'] ?? null,
                'sent_at' => $result['success'] ? now() : null
            ]);

            return $result;
            
        } catch (Exception $e) {
            error_log("Channel {$channel} error: " . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Préparer le message selon le canal et la langue
     */
    private function prepareMessage(string $type, array $data, string $channel, UserNotificationPreferences $preferences): array
    {
        $language = $preferences->language ?? 'fr';
        
        // Templates de base (à améliorer avec une vraie base de templates)
        $templates = [
            'fr' => [
                'booking_request' => [
                    'push' => ['title' => 'Nouvelle demande', 'body' => 'Vous avez reçu une nouvelle demande de réservation'],
                    'email' => ['subject' => 'Nouvelle demande de réservation', 'content' => 'Une nouvelle demande de réservation vous attend.'],
                ],
                'payment_received' => [
                    'push' => ['title' => 'Paiement reçu', 'body' => 'Votre paiement a été reçu avec succès'],
                    'email' => ['subject' => 'Confirmation de paiement', 'content' => 'Votre paiement a été traité avec succès.'],
                ]
            ],
            'en' => [
                'booking_request' => [
                    'push' => ['title' => 'New Request', 'body' => 'You received a new booking request'],
                    'email' => ['subject' => 'New booking request', 'content' => 'A new booking request is waiting for you.'],
                ],
                'payment_received' => [
                    'push' => ['title' => 'Payment received', 'body' => 'Your payment was received successfully'],
                    'email' => ['subject' => 'Payment confirmation', 'content' => 'Your payment has been processed successfully.'],
                ]
            ]
        ];

        return $templates[$language][$type][$channel] ?? [
            'title' => 'Notification',
            'body' => 'You have a new notification',
            'subject' => 'Notification',
            'content' => 'You have a new notification from KiloShare.'
        ];
    }

    /**
     * Obtenir le destinataire pour un canal
     */
    private function getRecipientForChannel(User $user, string $channel): string
    {
        switch ($channel) {
            case 'email':
                return $user->email;
            case 'sms':
                return $user->phone ?? '';
            case 'push':
                return $user->fcm_token ?? '';
            case 'in_app':
                return (string)$user->id;
            default:
                return '';
        }
    }

    /**
     * Obtenir le titre de notification par défaut
     */
    private function getNotificationTitle(string $type): string
    {
        $titles = [
            'booking_request' => 'Nouvelle demande',
            'booking_accepted' => 'Demande acceptée',
            'payment_received' => 'Paiement reçu',
            'trip_cancelled' => 'Voyage annulé',
        ];

        return $titles[$type] ?? 'Notification';
    }

    /**
     * Obtenir le message de notification par défaut
     */
    private function getNotificationMessage(string $type, array $data): string
    {
        $messages = [
            'booking_request' => 'Vous avez reçu une nouvelle demande de réservation',
            'booking_accepted' => 'Votre demande a été acceptée',
            'payment_received' => 'Votre paiement a été reçu avec succès',
            'trip_cancelled' => 'Un voyage a été annulé',
        ];

        return $messages[$type] ?? 'Vous avez une nouvelle notification';
    }
}