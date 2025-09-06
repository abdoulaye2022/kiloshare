<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\Notification;
use KiloShare\Models\NotificationLog;
use KiloShare\Models\NotificationTemplate;
use KiloShare\Models\UserNotificationPreference;
use KiloShare\Models\User;
use KiloShare\Services\Channels\PushNotificationChannel;
use KiloShare\Services\Channels\EmailNotificationChannel;
use KiloShare\Services\Channels\SmsNotificationChannel;
use KiloShare\Services\Channels\InAppNotificationChannel;
use Exception;

class NotificationService
{
    private array $channels = [];
    private array $rateLimiter = [];

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
     * Envoyer une notification à un utilisateur
     */
    public function send(
        int $userId,
        string $type,
        array $variables = [],
        array $options = []
    ): array {
        try {
            $user = User::find($userId);
            if (!$user) {
                throw new Exception("User not found: {$userId}");
            }

            // Obtenir les préférences utilisateur
            $preferences = $this->getUserPreferences($userId);
            
            // Déterminer quels canaux utiliser
            $channels = $this->getChannelsForNotification($type, $preferences, $options);
            
            if (empty($channels)) {
                return ['success' => false, 'error' => 'No channels available for user preferences'];
            }

            // Vérifier les limites de taux
            if ($this->isRateLimited($userId, $type)) {
                return ['success' => false, 'error' => 'Rate limited'];
            }

            // Créer la notification in-app
            $notification = $this->createNotification($userId, $type, $variables, $options);
            
            // Envoyer via chaque canal
            $results = [];
            foreach ($channels as $channel) {
                $results[$channel] = $this->sendToChannel($notification, $channel, $variables, $preferences);
            }

            // Mettre à jour le rate limiter
            $this->updateRateLimit($userId, $type);

            return ['success' => true, 'results' => $results, 'notification_id' => $notification->id];
            
        } catch (Exception $e) {
            error_log("Notification send error: " . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Envoyer une notification à plusieurs utilisateurs
     */
    public function sendToMultiple(
        array $userIds,
        string $type,
        array $variables = [],
        array $options = []
    ): array {
        $results = [];
        
        foreach ($userIds as $userId) {
            $results[$userId] = $this->send($userId, $type, $variables, $options);
        }
        
        return $results;
    }

    /**
     * Envoyer via un canal spécifique
     */
    private function sendToChannel(
        Notification $notification,
        string $channelName,
        array $variables,
        UserNotificationPreference $preferences
    ): array {
        try {
            if (!isset($this->channels[$channelName])) {
                throw new Exception("Unknown channel: {$channelName}");
            }

            $channel = $this->channels[$channelName];
            $user = $notification->user;

            // Obtenir le template
            $template = NotificationTemplate::findTemplate(
                $notification->type,
                $channelName,
                $preferences->language
            );

            if (!$template) {
                return ['success' => false, 'error' => "No template found for {$notification->type}:{$channelName}"];
            }

            // Rendre le template
            $rendered = $template->render($variables);

            // Obtenir le destinataire
            $recipient = $channel->getRecipient($user);
            if (!$recipient) {
                return ['success' => false, 'error' => "No recipient available for {$channelName}"];
            }

            // Créer le log
            $log = NotificationLog::createForNotification($notification, $channelName, $recipient);

            // Vérifier les heures silencieuses (sauf pour les critiques)
            if ($notification->priority !== 'critical' && $preferences->isInQuietHours() && $channelName === 'push') {
                $log->update(['status' => 'cancelled', 'error_message' => 'In quiet hours']);
                return ['success' => false, 'error' => 'In quiet hours'];
            }

            // Envoyer
            $result = $channel->send($user, $rendered, $notification->data ?? []);

            if ($result['success']) {
                $log->markAsSent();
                if (isset($result['provider_message_id'])) {
                    $log->update(['provider_message_id' => $result['provider_message_id']]);
                }
            } else {
                $log->markAsFailed($result['error'] ?? 'Unknown error');
            }

            return $result;

        } catch (Exception $e) {
            error_log("Channel send error [{$channelName}]: " . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Créer une notification in-app
     */
    private function createNotification(
        int $userId,
        string $type,
        array $variables,
        array $options
    ): Notification {
        // Obtenir le template in-app pour le titre et message de base
        $template = NotificationTemplate::findTemplate($type, 'in_app', $options['language'] ?? 'fr');
        
        if (!$template) {
            // Fallback générique
            $title = ucfirst(str_replace('_', ' ', $type));
            $message = 'Une nouvelle notification est disponible';
        } else {
            $rendered = $template->render($variables);
            $title = $rendered['title'] ?? ucfirst(str_replace('_', ' ', $type));
            $message = $rendered['message'] ?? 'Notification';
        }

        return Notification::createForUser(
            $userId,
            $type,
            $title,
            $message,
            $variables,
            $options['priority'] ?? 'normal',
            isset($options['expires_in_hours']) ? date('Y-m-d H:i:s', strtotime('+' . $options['expires_in_hours'] . ' hours')) : null
        );
    }

    /**
     * Obtenir les préférences utilisateur
     */
    private function getUserPreferences(int $userId): UserNotificationPreference
    {
        $preferences = UserNotificationPreference::where('user_id', $userId)->first();
        
        if (!$preferences) {
            // Créer des préférences par défaut
            $preferences = UserNotificationPreference::createForUser($userId);
        }
        
        return $preferences;
    }

    /**
     * Déterminer les canaux à utiliser
     */
    private function getChannelsForNotification(
        string $type,
        UserNotificationPreference $preferences,
        array $options
    ): array {
        $channels = [];

        // Toujours créer la notification in-app
        if ($preferences->canReceiveNotificationType($type, 'in_app')) {
            $channels[] = 'in_app';
        }

        // Push notifications
        if ($preferences->canReceiveNotificationType($type, 'push') && 
            !isset($options['channels']) || in_array('push', $options['channels'])) {
            $channels[] = 'push';
        }

        // Email pour certains types importants
        $emailTypes = [
            'booking_accepted', 'payment_confirmed', 'trip_cancelled', 
            'security_alert', 'account_suspended'
        ];
        if (in_array($type, $emailTypes) && $preferences->canReceiveNotificationType($type, 'email')) {
            $channels[] = 'email';
        }

        // SMS uniquement pour les codes et urgences
        $smsTypes = ['sms_pickup_code', 'sms_delivery_code', 'sms_verification'];
        if (in_array($type, $smsTypes) && $preferences->canReceiveNotificationType($type, 'sms')) {
            $channels[] = 'sms';
        }

        return array_unique($channels);
    }

    /**
     * Vérifier les limites de taux
     */
    private function isRateLimited(int $userId, string $type): bool
    {
        $now = time();
        $key = "{$userId}:{$type}";
        
        // Initialiser si pas existant
        if (!isset($this->rateLimiter[$userId])) {
            $this->rateLimiter[$userId] = [];
        }

        // Nettoyer les anciennes entrées (plus d'1 heure)
        $this->rateLimiter[$userId] = array_filter(
            $this->rateLimiter[$userId],
            fn($timestamp) => $timestamp > ($now - 3600)
        );

        // Vérifier la limite (max 3 par heure pour les push)
        $recentCount = count(array_filter(
            $this->rateLimiter[$userId],
            fn($timestamp) => $timestamp > ($now - 3600)
        ));

        return $recentCount >= 3;
    }

    /**
     * Mettre à jour le rate limiter
     */
    private function updateRateLimit(int $userId, string $type): void
    {
        if (!isset($this->rateLimiter[$userId])) {
            $this->rateLimiter[$userId] = [];
        }
        
        $this->rateLimiter[$userId][] = time();
    }

    /**
     * Traiter la queue de notifications
     */
    public function processQueue(): int
    {
        $processed = 0;
        
        // Récupérer les notifications en attente
        $queueItems = \KiloShare\Models\NotificationQueue::where('status', 'pending')
            ->where('scheduled_at', '<=', date('Y-m-d H:i:s'))
            ->where(function ($query) {
                $query->whereNull('expires_at')
                      ->orWhere('expires_at', '>', date('Y-m-d H:i:s'));
            })
            ->orderBy('priority', 'desc')
            ->orderBy('scheduled_at', 'asc')
            ->limit(50)
            ->get();

        foreach ($queueItems as $item) {
            try {
                $item->update(['status' => 'processing']);
                
                $result = $this->send(
                    $item->user_id,
                    $item->type,
                    $item->data ?? []
                );
                
                if ($result['success']) {
                    $item->update(['status' => 'sent']);
                    $processed++;
                } else {
                    $item->update([
                        'status' => 'failed',
                        'attempts' => $item->attempts + 1,
                        'error_message' => $result['error'],
                        'last_attempt_at' => date('Y-m-d H:i:s'),
                        'next_attempt_at' => $item->attempts < $item->max_attempts 
                            ? date('Y-m-d H:i:s', strtotime('+' . pow(5, $item->attempts) . ' minutes')) 
                            : null
                    ]);
                }
                
            } catch (Exception $e) {
                $item->update([
                    'status' => 'failed',
                    'error_message' => $e->getMessage(),
                    'attempts' => $item->attempts + 1,
                    'last_attempt_at' => date('Y-m-d H:i:s'),
                ]);
            }
        }

        return $processed;
    }

    /**
     * Ajouter une notification à la queue
     */
    public function queue(
        int $userId,
        string $type,
        array $variables = [],
        array $options = []
    ): bool {
        try {
            \KiloShare\Models\NotificationQueue::create([
                'user_id' => $userId,
                'type' => $type,
                'channel' => $options['channel'] ?? 'push',
                'priority' => $options['priority'] ?? 'normal',
                'scheduled_at' => isset($options['delay_minutes']) 
                    ? date('Y-m-d H:i:s', strtotime('+' . $options['delay_minutes'] . ' minutes'))
                    : date('Y-m-d H:i:s'),
                'expires_at' => isset($options['expires_in_hours']) 
                    ? date('Y-m-d H:i:s', strtotime('+' . $options['expires_in_hours'] . ' hours')) 
                    : null,
                'recipient' => $options['recipient'] ?? '',
                'title' => $options['title'] ?? '',
                'message' => $options['message'] ?? '',
                'data' => $variables,
            ]);
            
            return true;
        } catch (Exception $e) {
            error_log("Queue notification error: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Obtenir les statistiques
     */
    public function getStats(int $days = 30): array
    {
        $stats = NotificationLog::getStatsByChannel($days);
        
        return [
            'period_days' => $days,
            'channels' => $stats,
            'total_sent' => array_sum(array_column($stats, 'sent')),
            'total_delivered' => array_sum(array_column($stats, 'delivered')),
            'total_opened' => array_sum(array_column($stats, 'opened')),
            'total_failed' => array_sum(array_column($stats, 'failed')),
        ];
    }
}