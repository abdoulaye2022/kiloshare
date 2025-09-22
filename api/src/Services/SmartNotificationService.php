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
use Carbon\Carbon;

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
            'created_at' => Carbon::now()
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
                'created_at' => Carbon::now()
            ]);

            // Envoyer
            $result = $channelService->send($user, $message, $data);
            
            // Mettre à jour le log
            $log->update([
                'status' => $result['success'] ? 'sent' : 'failed',
                'error_message' => $result['error'] ?? null,
                'sent_at' => $result['success'] ? Carbon::now() : null
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

    /**
     * Envoyer une notification d'autorisation de paiement
     */
    public function sendPaymentAuthorizationNotification($authorization, $user): bool
    {
        try {
            $result = $this->send(
                $user->id,
                'payment_authorized',
                [
                    'booking_id' => $authorization->booking_id,
                    'amount' => $authorization->getAmountInDollars(),
                    'currency' => $authorization->currency,
                ],
                [
                    'channels' => ['push', 'in_app'],
                    'priority' => 'normal'
                ]
            );

            return $result['success'] ?? false;
        } catch (\Exception $e) {
            error_log("Erreur notification autorisation paiement: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification de paiement annulé
     */
    public function sendPaymentCancelledNotification($authorization, ?string $reason = null): bool
    {
        try {
            $senderResult = true;
            $transporterResult = true;

            // Notifier l'expéditeur
            if ($authorization->booking && $authorization->booking->sender_id) {
                $senderResult = $this->send(
                    $authorization->booking->sender_id,
                    'payment_cancelled',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                        'reason' => $reason,
                    ],
                    [
                        'channels' => ['push', 'in_app', 'email'],
                        'priority' => 'high'
                    ]
                )['success'] ?? false;
            }

            // Notifier le transporteur (vérifier que les relations existent)
            if ($authorization->booking && $authorization->booking->trip && $authorization->booking->trip->user_id) {
                $transporterResult = $this->send(
                    $authorization->booking->trip->user_id,
                    'payment_cancelled_transporter',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                        'reason' => $reason,
                    ],
                    [
                        'channels' => ['push', 'in_app'],
                        'priority' => 'normal'
                    ]
                )['success'] ?? false;
            }

            return $senderResult && $transporterResult;
        } catch (\Exception $e) {
            error_log("Erreur notification paiement annulé: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification de paiement confirmé
     */
    public function sendPaymentConfirmedNotification($authorization): bool
    {
        try {
            $senderResult = true;
            $transporterResult = true;

            // Notifier l'expéditeur
            if ($authorization->booking && $authorization->booking->sender_id) {
                $senderResult = $this->send(
                    $authorization->booking->sender_id,
                    'payment_confirmed',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                    ],
                    [
                        'channels' => ['push', 'in_app'],
                        'priority' => 'normal'
                    ]
                )['success'] ?? false;
            }

            // Notifier le transporteur
            if ($authorization->booking && $authorization->booking->trip && $authorization->booking->trip->user_id) {
                $transporterResult = $this->send(
                    $authorization->booking->trip->user_id,
                    'payment_confirmed_transporter',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                    ],
                    [
                        'channels' => ['push', 'in_app'],
                        'priority' => 'normal'
                    ]
                )['success'] ?? false;
            }

            return $senderResult && $transporterResult;
        } catch (\Exception $e) {
            error_log("Erreur notification paiement confirmé: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification de paiement capturé
     */
    public function sendPaymentCapturedNotification($authorization): bool
    {
        try {
            $senderResult = true;
            $transporterResult = true;

            // Notifier l'expéditeur
            if ($authorization->booking && $authorization->booking->sender_id) {
                $senderResult = $this->send(
                    $authorization->booking->sender_id,
                    'payment_captured',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                    ],
                    [
                        'channels' => ['push', 'in_app'],
                        'priority' => 'normal'
                    ]
                )['success'] ?? false;
            }

            // Notifier le transporteur
            if ($authorization->booking && $authorization->booking->trip && $authorization->booking->trip->user_id) {
                $transporterResult = $this->send(
                    $authorization->booking->trip->user_id,
                    'payment_captured_transporter',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                    ],
                    [
                        'channels' => ['push', 'in_app'],
                        'priority' => 'normal'
                    ]
                )['success'] ?? false;
            }

            return $senderResult && $transporterResult;
        } catch (\Exception $e) {
            error_log("Erreur notification paiement capturé: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer une notification de paiement expiré
     */
    public function sendPaymentExpiredNotification($authorization): bool
    {
        try {
            $senderResult = true;
            $transporterResult = true;

            // Notifier l'expéditeur
            if ($authorization->booking && $authorization->booking->sender_id) {
                $senderResult = $this->send(
                    $authorization->booking->sender_id,
                    'payment_expired',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                    ],
                    [
                        'channels' => ['push', 'in_app', 'email'],
                        'priority' => 'high'
                    ]
                )['success'] ?? false;
            }

            // Notifier le transporteur
            if ($authorization->booking && $authorization->booking->trip && $authorization->booking->trip->user_id) {
                $transporterResult = $this->send(
                    $authorization->booking->trip->user_id,
                    'payment_expired_transporter',
                    [
                        'booking_id' => $authorization->booking_id,
                        'amount' => $authorization->getAmountInDollars(),
                        'currency' => $authorization->currency,
                    ],
                    [
                        'channels' => ['push', 'in_app'],
                        'priority' => 'normal'
                    ]
                )['success'] ?? false;
            }

            return $senderResult && $transporterResult;
        } catch (\Exception $e) {
            error_log("Erreur notification paiement expiré: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notifier qu'un paiement a été capturé automatiquement
     */
    public function notifyPaymentCaptured(User $user, $booking, string $message): bool
    {
        try {
            return $this->send(
                $user->id,
                'payment_captured',
                [
                    'booking_id' => $booking->id,
                    'trip_id' => $booking->trip_id,
                    'amount' => $booking->final_price ?? $booking->proposed_price,
                    'currency' => $booking->trip->currency ?? 'CAD',
                    'message' => $message,
                    'delivery_confirmed' => true,
                ],
                [
                    'channels' => ['push', 'in_app', 'email'],
                    'priority' => 'high'
                ]
            )['success'] ?? false;
        } catch (\Exception $e) {
            error_log("Erreur notification capture paiement: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notifier qu'un transporteur a reçu le paiement
     */
    public function notifyPaymentReceived(User $user, $booking, string $message): bool
    {
        try {
            return $this->send(
                $user->id,
                'payment_received',
                [
                    'booking_id' => $booking->id,
                    'trip_id' => $booking->trip_id,
                    'amount' => $booking->final_price ?? $booking->proposed_price,
                    'currency' => $booking->trip->currency ?? 'CAD',
                    'message' => $message,
                    'delivery_confirmed' => true,
                ],
                [
                    'channels' => ['push', 'in_app'],
                    'priority' => 'high'
                ]
            )['success'] ?? false;
        } catch (\Exception $e) {
            error_log("Erreur notification réception paiement: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notifier que le compte Stripe est requis
     */
    public function sendStripeAccountRequiredNotification($authorization, $user): bool
    {
        try {
            $result = $this->send(
                $user->id,
                'stripe_account_required',
                [
                    'booking_id' => $authorization->booking_id,
                    'amount' => $authorization->getAmountInDollars(),
                    'currency' => $authorization->currency,
                ],
                [
                    'channels' => ['push', 'in_app', 'email'],
                    'priority' => 'high'
                ]
            );

            return $result['success'] ?? false;
        } catch (\Exception $e) {
            error_log("Erreur notification compte Stripe requis: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notification d'annulation intelligente avec conséquences
     */
    public function sendTripCancelledNotification($user, $trip, $data = [])
    {
        $severity = $data['severity'] ?? 'medium';
        $cancellationType = $data['cancellation_type'] ?? 'standard';

        $messages = [
            'free_cancellation' => "Votre voyage {$trip->title} a été annulé",
            'impact_cancellation' => "Votre voyage {$trip->title} a été annulé - Des utilisateurs étaient intéressés",
            'critical_cancellation' => "Annulation critique: Votre voyage {$trip->title} a été annulé - Remboursements en cours",
            'booking_cancellation' => "Votre voyage {$trip->title} a été annulé - Réservations impactées"
        ];

        $message = $messages[$cancellationType] ?? "Votre voyage {$trip->title} a été annulé";
        $channels = $severity === 'high' ? ['push', 'in_app', 'email'] : ['push', 'in_app'];

        return $this->send(
            $user->id,
            'intelligent_trip_cancelled',
            array_merge([
                'trip_id' => $trip->id,
                'trip_title' => $trip->title,
                'cancellation_type' => $cancellationType,
                'severity' => $severity,
                'departure_date' => $trip->departure_date,
                'message' => $message
            ], $data),
            [
                'channels' => $channels,
                'priority' => $severity === 'high' ? 'high' : 'normal'
            ]
        )['success'] ?? false;
    }

    /**
     * Notification de suggestion d'alternative
     */
    public function sendAlternativeSuggestedNotification($user, $originalTrip, $suggestedTrip, $data = [])
    {
        return $this->send(
            $user->id,
            'alternative_suggested',
            array_merge([
                'original_trip_id' => $originalTrip->id,
                'suggested_trip_id' => $suggestedTrip->id,
                'suggested_trip_title' => $suggestedTrip->title,
                'departure_date' => $suggestedTrip->departure_date,
                'price_per_kg' => $suggestedTrip->price_per_kg,
                'message' => "Une alternative a été trouvée pour remplacer votre voyage annulé vers {$originalTrip->arrival_city}"
            ], $data),
            ['channels' => ['push', 'in_app']]
        )['success'] ?? false;
    }

    /**
     * Notification de remboursement traité
     */
    public function sendRefundNotification($user, $booking, $data = [])
    {
        $amount = $data['amount'] ?? 0;
        $refundType = $data['refund_type'] ?? 'standard';
        $processingTime = $data['processing_time'] ?? '3-5 jours ouvrables';

        return $this->send(
            $user->id,
            'refund_processed',
            array_merge([
                'booking_id' => $booking->id,
                'trip_id' => $booking->trip_id,
                'amount' => $amount,
                'refund_type' => $refundType,
                'processing_time' => $processingTime,
                'message' => "Votre remboursement de {$amount}€ est en cours de traitement"
            ], $data),
            ['channels' => ['push', 'in_app', 'email']]
        )['success'] ?? false;
    }

    /**
     * Notification de pénalité appliquée
     */
    public function sendPenaltyNotification($user, $penaltyType, $duration, $data = [])
    {
        $messages = [
            'warning' => 'Attention: Surveillez vos annulations futures',
            'publication_restriction' => "Restriction de publication pendant {$duration} jours",
            'account_suspension' => "Compte suspendu pendant {$duration} jours"
        ];

        $message = $messages[$penaltyType] ?? "Pénalité appliquée: {$penaltyType}";

        return $this->send(
            $user->id,
            'penalty_applied',
            array_merge([
                'penalty_type' => $penaltyType,
                'duration_days' => $duration,
                'message' => $message
            ], $data),
            [
                'channels' => ['push', 'in_app', 'email'],
                'priority' => 'high'
            ]
        )['success'] ?? false;
    }

    /**
     * Notification pour les favoris d'un voyage annulé
     */
    public function sendFavoritesCancellationNotification($user, $trip, $data = [])
    {
        return $this->send(
            $user->id,
            'favorite_trip_cancelled',
            array_merge([
                'trip_id' => $trip->id,
                'trip_title' => $trip->title,
                'departure_city' => $trip->departure_city,
                'arrival_city' => $trip->arrival_city,
                'departure_date' => $trip->departure_date,
                'message' => "Un voyage que vous avez mis en favoris ({$trip->title}) a été annulé"
            ], $data),
            ['channels' => ['push', 'in_app']]
        )['success'] ?? false;
    }
}