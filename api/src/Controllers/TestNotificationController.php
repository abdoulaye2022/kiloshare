<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Services\SmartNotificationService;
use KiloShare\Models\UserNotificationPreferences;
use KiloShare\Models\User;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use KiloShare\Utils\Response;

class TestNotificationController
{
    private SmartNotificationService $notificationService;

    public function __construct()
    {
        $this->notificationService = new SmartNotificationService();
    }

    /**
     * Envoyer une notification de test
     */
    public function sendTest(ServerRequestInterface $request): ResponseInterface
    {
        $userId = $request->getAttribute('user_id');
        $body = json_decode($request->getBody()->getContents(), true);
        
        $type = $body['type'] ?? 'booking_request';
        $data = $body['data'] ?? [];
        
        try {
            $result = $this->notificationService->send($userId, $type, $data);
            
            return Response::success([
                'message' => 'Test notification sent',
                'result' => $result
            ]);
            
        } catch (\Exception $e) {
            return Response::error('Failed to send notification: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Tester toutes les préférences
     */
    public function testAllPreferences(ServerRequestInterface $request): ResponseInterface
    {
        $userId = $request->getAttribute('user_id');
        
        try {
            $user = User::find($userId);
            if (!$user) {
                return Response::error('User not found', 404);
            }

            // Obtenir les préférences actuelles
            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            if (!$preferences) {
                $preferences = UserNotificationPreferences::createForUser($userId);
            }

            // Tester différents scénarios
            $scenarios = [
                [
                    'name' => 'Demande de réservation',
                    'type' => 'booking_request',
                    'data' => ['trip_id' => 123, 'sender' => 'Jean Dupont']
                ],
                [
                    'name' => 'Paiement reçu',  
                    'type' => 'payment_received',
                    'data' => ['amount' => 50.00, 'currency' => 'EUR']
                ],
                [
                    'name' => 'Voyage annulé',
                    'type' => 'trip_cancelled', 
                    'data' => ['trip_id' => 456, 'reason' => 'Imprévu']
                ],
                [
                    'name' => 'Alerte sécurité',
                    'type' => 'login_from_new_device',
                    'data' => ['device' => 'iPhone', 'location' => 'Paris']
                ]
            ];

            $results = [];
            foreach ($scenarios as $scenario) {
                $results[] = [
                    'scenario' => $scenario['name'],
                    'type' => $scenario['type'],
                    'result' => $this->notificationService->send($userId, $scenario['type'], $scenario['data'])
                ];
            }

            return Response::success([
                'message' => 'All test scenarios executed',
                'user_preferences' => $preferences->toApiArray(),
                'results' => $results
            ]);

        } catch (\Exception $e) {
            return Response::error('Test failed: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Simuler différentes préférences
     */
    public function testWithPreferences(ServerRequestInterface $request): ResponseInterface
    {
        $userId = $request->getAttribute('user_id');
        $body = json_decode($request->getBody()->getContents(), true);
        
        try {
            $user = User::find($userId);
            if (!$user) {
                return Response::error('User not found', 404);
            }

            // Créer ou obtenir les préférences
            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            if (!$preferences) {
                $preferences = UserNotificationPreferences::createForUser($userId);
            }

            // Sauvegarder les préférences originales
            $originalPrefs = $preferences->toArray();

            // Appliquer les préférences de test
            if (isset($body['preferences'])) {
                $preferences->update($body['preferences']);
            }

            // Envoyer la notification de test
            $notificationType = $body['type'] ?? 'booking_request';
            $notificationData = $body['data'] ?? [];
            
            $result = $this->notificationService->send($userId, $notificationType, $notificationData);

            // Restaurer les préférences originales
            $preferences->update($originalPrefs);

            return Response::success([
                'message' => 'Test with custom preferences completed',
                'applied_preferences' => $body['preferences'] ?? [],
                'notification_type' => $notificationType,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            return Response::error('Test failed: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Obtenir l'état des canaux pour un utilisateur
     */
    public function getChannelStatus(ServerRequestInterface $request): ResponseInterface
    {
        $userId = $request->getAttribute('user_id');
        
        try {
            $user = User::find($userId);
            if (!$user) {
                return Response::error('User not found', 404);
            }

            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            if (!$preferences) {
                return Response::error('No preferences found', 404);
            }

            $channelStatus = [
                'push' => [
                    'enabled_globally' => $preferences->push_enabled,
                    'fcm_token_available' => !empty($user->fcm_token),
                    'categories' => [
                        'trip_updates' => $preferences->trip_updates_push,
                        'booking_updates' => $preferences->booking_updates_push,
                        'payment_updates' => $preferences->payment_updates_push,
                        'security_alerts' => $preferences->security_alerts_push,
                    ]
                ],
                'email' => [
                    'enabled_globally' => $preferences->email_enabled,
                    'email_available' => !empty($user->email),
                    'categories' => [
                        'trip_updates' => $preferences->trip_updates_email,
                        'booking_updates' => $preferences->booking_updates_email,
                        'payment_updates' => $preferences->payment_updates_email,
                        'security_alerts' => $preferences->security_alerts_email,
                    ]
                ],
                'sms' => [
                    'enabled_globally' => $preferences->sms_enabled,
                    'phone_available' => !empty($user->phone),
                ],
                'in_app' => [
                    'enabled_globally' => $preferences->in_app_enabled,
                ],
                'quiet_hours' => [
                    'enabled' => $preferences->quiet_hours_enabled,
                    'start' => $preferences->quiet_hours_start,
                    'end' => $preferences->quiet_hours_end,
                    'timezone' => $preferences->timezone,
                    'currently_in_quiet_hours' => !$preferences->canReceiveNotificationNow(),
                ]
            ];

            return Response::success([
                'user_id' => $userId,
                'channel_status' => $channelStatus
            ]);

        } catch (\Exception $e) {
            return Response::error('Failed to get channel status: ' . $e->getMessage(), 500);
        }
    }
}