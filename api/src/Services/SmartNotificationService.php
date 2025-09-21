<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\UserNotificationPreferences;
use KiloShare\Models\User;
use KiloShare\Models\Notification;
use KiloShare\Models\NotificationLog;
use KiloShare\Models\NotificationTemplate;
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
            'journey_started' => 'trip_updates',
            
            // Notifications de réservations
            'booking_request' => 'booking_updates',
            'booking_accepted' => 'booking_updates',
            'booking_rejected' => 'booking_updates',
            'booking_cancelled' => 'booking_updates',
            'booking_confirmed' => 'booking_updates',
            'delivery_code_generated' => 'delivery_updates',
            'delivery_code_regenerated' => 'delivery_updates',
            'delivery_confirmed' => 'delivery_updates',
            
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
                'title' => $message['title'] ?? $message['subject'] ?? 'Notification',
                'message' => $message['content'] ?? $message['body'] ?? $message['message'] ?? '',
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
     * Préparer le message selon le canal et la langue en utilisant les templates de la DB
     */
    private function prepareMessage(string $type, array $data, string $channel, UserNotificationPreferences $preferences): array
    {
        $language = $preferences->language ?? 'fr';
        
        try {
            // Chercher le template dans la base de données
            $template = NotificationTemplate::findTemplate($type, $channel, $language);
            
            if ($template) {
                // Utiliser le template de la DB
                $rendered = $template->render($data);
                
                // Mapper les champs selon le canal
                return $this->mapTemplateFields($rendered, $channel);
            }
            
            // Fallback : templates par défaut si pas trouvé en DB
            error_log("No template found for type: {$type}, channel: {$channel}, language: {$language}");
            return $this->getFallbackTemplate($type, $channel, $language);
            
        } catch (\Exception $e) {
            error_log("Error preparing message: " . $e->getMessage());
            return $this->getFallbackTemplate($type, $channel, $language);
        }
    }

    /**
     * Mapper les champs du template selon le canal
     */
    private function mapTemplateFields(array $rendered, string $channel): array
    {
        switch ($channel) {
            case 'push':
                return [
                    'title' => $rendered['title'] ?? '',
                    'body' => $rendered['message'] ?? '',
                    'content' => $rendered['message'] ?? '' // Ajout pour cohérence
                ];
                
            case 'email':
                return [
                    'title' => $rendered['title'] ?? '',
                    'subject' => $rendered['subject'] ?? $rendered['title'] ?? '',
                    'content' => $rendered['html_content'] ?? $rendered['message'] ?? '',
                    'plain_content' => $rendered['message'] ?? ''
                ];
                
            case 'sms':
                return [
                    'title' => $rendered['title'] ?? '',
                    'content' => $rendered['message'] ?? ''
                ];
                
            case 'in_app':
                return [
                    'title' => $rendered['title'] ?? '',
                    'content' => $rendered['message'] ?? '',
                    'message' => $rendered['message'] ?? '',
                    'html_content' => $rendered['html_content'] ?? null
                ];
                
            default:
                return $rendered;
        }
    }

    /**
     * Templates de fallback si pas trouvé en DB
     */
    private function getFallbackTemplate(string $type, string $channel, string $language): array
    {
        $fallbacks = [
            'fr' => [
                'new_booking_request' => [
                    'push' => ['title' => 'Nouvelle demande', 'body' => 'Vous avez reçu une nouvelle demande de réservation'],
                ],
                'booking_accepted' => [
                    'push' => ['title' => 'Demande acceptée', 'body' => 'Votre demande a été acceptée'],
                ],
                'booking_rejected' => [
                    'push' => ['title' => 'Demande refusée', 'body' => 'Votre demande a été refusée'],
                ],
                'payment_received' => [
                    'push' => ['title' => 'Paiement reçu', 'body' => 'Paiement reçu avec succès'],
                ],
                'payment_confirmed' => [
                    'push' => ['title' => 'Paiement confirmé', 'body' => 'Votre paiement a été confirmé'],
                ],
                'booking_cancelled' => [
                    'push' => ['title' => 'Réservation annulée', 'body' => 'Une réservation a été annulée'],
                ],
                'journey_started' => [
                    'push' => ['title' => '✈️ Voyage commencé !', 'body' => 'Votre transporteur a commencé le voyage'],
                    'email' => ['title' => 'Voyage commencé', 'subject' => '✈️ Votre voyage KiloShare a commencé !', 'content' => 'Votre transporteur a commencé le voyage. Vous serez notifié de la livraison.'],
                ],
                'delivery_code_generated' => [
                    'push' => ['title' => '🔐 Code de livraison', 'body' => 'Votre code de livraison a été généré'],
                    'email' => ['title' => 'Code de livraison', 'subject' => '🔐 Code de livraison pour votre colis', 'content' => 'Votre code de livraison est disponible. Gardez-le précieusement !'],
                ],
                'delivery_code_regenerated' => [
                    'push' => ['title' => '🔄 Nouveau code', 'body' => 'Un nouveau code de livraison a été généré'],
                    'email' => ['title' => 'Nouveau code', 'subject' => '🔄 Nouveau code de livraison généré', 'content' => 'Votre ancien code a été remplacé par un nouveau code.'],
                ],
                'delivery_confirmed' => [
                    'push' => ['title' => '✅ Livraison confirmée', 'body' => 'La livraison a été confirmée avec succès'],
                    'email' => ['title' => 'Livraison confirmée', 'subject' => '✅ Livraison confirmée avec succès', 'content' => 'Votre colis a été livré et confirmé avec le code de livraison.'],
                ]
            ]
        ];

        $template = $fallbacks[$language][$type][$channel] ?? [
            'title' => 'Notification',
            'body' => 'Vous avez une nouvelle notification'
        ];

        return $this->mapTemplateFields($template, $channel);
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

    /**
     * Notifier la génération d'un code de livraison (à l'expéditeur)
     */
    public function sendDeliveryCodeGenerated(User $sender, string $code, $booking): array
    {
        return $this->send(
            $sender->id,
            'delivery_code_generated',
            [
                'delivery_code' => $code,
                'booking_id' => $booking->id,
                'booking_reference' => $booking->uuid,
                'package_description' => $booking->package_description,
                'receiver_name' => $booking->receiver->first_name,
                'trip_route' => $booking->trip->departure_city . ' → ' . $booking->trip->arrival_city,
            ],
            ['priority' => 'high']
        );
    }

    /**
     * Notifier la régénération d'un code de livraison
     */
    public function sendDeliveryCodeRegenerated(User $sender, string $newCode, $booking): array
    {
        return $this->send(
            $sender->id,
            'delivery_code_regenerated',
            [
                'new_delivery_code' => $newCode,
                'booking_id' => $booking->id,
                'booking_reference' => $booking->uuid,
                'package_description' => $booking->package_description,
                'trip_route' => $booking->trip->departure_city . ' → ' . $booking->trip->arrival_city,
            ],
            ['priority' => 'high']
        );
    }

    /**
     * Notifier la confirmation de livraison
     */
    public function sendDeliveryConfirmed(User $user, $booking): array
    {
        $isReceiver = $user->id === $booking->receiver_id;

        return $this->send(
            $user->id,
            'delivery_confirmed',
            [
                'booking_id' => $booking->id,
                'booking_reference' => $booking->uuid,
                'package_description' => $booking->package_description,
                'sender_name' => $booking->sender->first_name,
                'receiver_name' => $booking->receiver->first_name,
                'trip_route' => $booking->trip->departure_city . ' → ' . $booking->trip->arrival_city,
                'is_receiver' => $isReceiver,
                'confirmed_at' => $booking->delivery_confirmed_at->format('d/m/Y à H:i'),
            ],
            ['priority' => 'high']
        );
    }
}