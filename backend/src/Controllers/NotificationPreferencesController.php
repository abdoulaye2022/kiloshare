<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use KiloShare\Models\UserNotificationPreferences;
use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Exception;

class NotificationPreferencesController
{
    /**
     * Obtenir les préférences de notification de l'utilisateur connecté
     */
    public function getUserPreferences(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $userId = $request->getAttribute('user_id');
            if (!$userId) {
                return Response::unauthorized('Non autorisé');
            }
            
            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            
            // Si pas de préférences, créer les préférences par défaut
            if (!$preferences) {
                $preferences = UserNotificationPreferences::createDefaultForUser($userId);
            }

            return Response::success([
                'preferences' => $preferences->toApiArray()
            ], 'Préférences de notification récupérées avec succès');

        } catch (Exception $e) {
            return Response::serverError('Erreur lors de la récupération des préférences: ' . $e->getMessage());
        }
    }

    /**
     * Mettre à jour les préférences de notification de l'utilisateur connecté
     */
    public function updateUserPreferences(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $userId = $request->getAttribute('user_id');
            if (!$userId) {
                return Response::unauthorized('Non autorisé');
            }

            $data = json_decode($request->getBody()->getContents(), true);
            if (!$data) {
                return Response::badRequest('Données JSON invalides');
            }

            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            
            // Si pas de préférences, créer les préférences par défaut
            if (!$preferences) {
                $preferences = UserNotificationPreferences::createDefaultForUser($userId);
            }

            // Validation des données
            $updateData = $this->validatePreferencesData($data);
            
            // Mise à jour des préférences
            $preferences->update($updateData);

            return Response::success([
                'preferences' => $preferences->fresh()->toApiArray()
            ], 'Préférences mises à jour avec succès');

        } catch (Exception $e) {
            return Response::badRequest('Erreur lors de la mise à jour des préférences: ' . $e->getMessage());
        }
    }

    /**
     * [ADMIN] Obtenir les statistiques des préférences de notification
     */
    public function getPreferencesStats(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $totalUsers = User::count();
            $usersWithPreferences = UserNotificationPreferences::count();
            
            $stats = [
                'total_users' => $totalUsers,
                'users_with_preferences' => $usersWithPreferences,
                'users_without_preferences' => $totalUsers - $usersWithPreferences,
                'notification_channels' => [
                    'push_enabled' => UserNotificationPreferences::where('push_enabled', true)->count(),
                    'email_enabled' => UserNotificationPreferences::where('email_enabled', true)->count(),
                    'sms_enabled' => UserNotificationPreferences::where('sms_enabled', true)->count(),
                    'in_app_enabled' => UserNotificationPreferences::where('in_app_enabled', true)->count(),
                    'marketing_enabled' => UserNotificationPreferences::where('marketing_enabled', true)->count()
                ],
                'notification_types' => [
                    'trip_updates_push' => UserNotificationPreferences::where('trip_updates_push', true)->count(),
                    'booking_updates_push' => UserNotificationPreferences::where('booking_updates_push', true)->count(),
                    'payment_updates_push' => UserNotificationPreferences::where('payment_updates_push', true)->count(),
                    'security_alerts_push' => UserNotificationPreferences::where('security_alerts_push', true)->count()
                ],
                'quiet_hours' => [
                    'enabled' => UserNotificationPreferences::where('quiet_hours_enabled', true)->count(),
                    'disabled' => UserNotificationPreferences::where('quiet_hours_enabled', false)->count()
                ],
                'languages' => UserNotificationPreferences::selectRaw('language, COUNT(*) as count')
                    ->groupBy('language')
                    ->get()
                    ->pluck('count', 'language')
                    ->toArray(),
                'timezones' => UserNotificationPreferences::selectRaw('timezone, COUNT(*) as count')
                    ->groupBy('timezone')
                    ->orderBy('count', 'desc')
                    ->limit(10)
                    ->get()
                    ->pluck('count', 'timezone')
                    ->toArray()
            ];

            return Response::success([
                'stats' => $stats
            ], 'Statistiques des préférences récupérées avec succès');

        } catch (Exception $e) {
            return Response::serverError('Erreur lors de la récupération des statistiques: ' . $e->getMessage());
        }
    }

    /**
     * [ADMIN] Obtenir les préférences d'un utilisateur spécifique
     */
    public function getAdminUserPreferences(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $route = $request->getAttribute('route');
            $userId = (int)$route->getArgument('userId');
            
            // Vérifier que l'utilisateur existe
            $user = User::find($userId);
            if (!$user) {
                return Response::notFound('Utilisateur non trouvé');
            }

            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            
            // Si pas de préférences, créer les préférences par défaut
            if (!$preferences) {
                $preferences = UserNotificationPreferences::createDefaultForUser($userId);
            }

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'email' => $user->email
                ],
                'preferences' => $preferences->toApiArray()
            ], 'Préférences de notification récupérées avec succès');

        } catch (Exception $e) {
            return Response::serverError('Erreur lors de la récupération des préférences: ' . $e->getMessage());
        }
    }

    /**
     * [ADMIN] Mettre à jour les préférences d'un utilisateur spécifique
     */
    public function updateAdminUserPreferences(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $route = $request->getAttribute('route');
            $userId = (int)$route->getArgument('userId');
            $data = json_decode($request->getBody()->getContents(), true);
            
            if (!$data) {
                return Response::badRequest('Données JSON invalides');
            }
            
            // Vérifier que l'utilisateur existe
            $user = User::find($userId);
            if (!$user) {
                return Response::notFound('Utilisateur non trouvé');
            }

            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            
            // Si pas de préférences, créer les préférences par défaut
            if (!$preferences) {
                $preferences = UserNotificationPreferences::createDefaultForUser($userId);
            }

            // Validation des données
            $updateData = $this->validatePreferencesData($data);
            
            // Mise à jour des préférences
            $preferences->update($updateData);

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'email' => $user->email
                ],
                'preferences' => $preferences->fresh()->toApiArray()
            ], 'Préférences mises à jour avec succès');

        } catch (Exception $e) {
            return Response::badRequest('Erreur lors de la mise à jour des préférences: ' . $e->getMessage());
        }
    }

    /**
     * Réinitialiser les préférences aux valeurs par défaut
     */
    public function resetToDefaults(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $userId = $request->getAttribute('user_id');
            if (!$userId) {
                return Response::unauthorized('Non autorisé');
            }
            
            $preferences = UserNotificationPreferences::where('user_id', $userId)->first();
            
            if ($preferences) {
                $preferences->delete();
            }
            
            // Recréer avec les valeurs par défaut
            $newPreferences = UserNotificationPreferences::createDefaultForUser($userId);

            return Response::success([
                'preferences' => $newPreferences->toApiArray()
            ], 'Préférences réinitialisées aux valeurs par défaut');

        } catch (Exception $e) {
            return Response::serverError('Erreur lors de la réinitialisation des préférences: ' . $e->getMessage());
        }
    }

    /**
     * Valider les données de préférences
     */
    private function validatePreferencesData(array $data): array
    {
        $allowedFields = [
            'push_enabled', 'email_enabled', 'sms_enabled', 'in_app_enabled', 'marketing_enabled',
            'quiet_hours_enabled', 'quiet_hours_start', 'quiet_hours_end', 'timezone',
            'trip_updates_push', 'trip_updates_email', 'booking_updates_push', 'booking_updates_email',
            'payment_updates_push', 'payment_updates_email', 'security_alerts_push', 'security_alerts_email',
            'language'
        ];

        $validated = [];
        
        foreach ($allowedFields as $field) {
            if (array_key_exists($field, $data)) {
                $value = $data[$field];
                
                // Validation spécifique par champ
                switch ($field) {
                    case 'quiet_hours_start':
                    case 'quiet_hours_end':
                        if (!preg_match('/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/', $value)) {
                            throw new Exception("Format d'heure invalide pour {$field}. Utilisez HH:mm:ss");
                        }
                        break;
                        
                    case 'timezone':
                        $validTimezones = timezone_identifiers_list();
                        if (!in_array($value, $validTimezones)) {
                            throw new Exception("Timezone invalide: {$value}");
                        }
                        break;
                        
                    case 'language':
                        $validLanguages = ['fr', 'en', 'es', 'de', 'it'];
                        if (!in_array($value, $validLanguages)) {
                            throw new Exception("Langue invalide: {$value}");
                        }
                        break;
                        
                    default:
                        // Pour les champs boolean
                        if (str_ends_with($field, '_enabled') || str_ends_with($field, '_push') || str_ends_with($field, '_email')) {
                            $value = (bool)$value;
                        }
                        break;
                }
                
                $validated[$field] = $value;
            }
        }

        return $validated;
    }
}