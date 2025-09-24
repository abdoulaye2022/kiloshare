<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use KiloShare\Services\FirebaseNotificationService;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use KiloShare\Utils\JWTHelper;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class SocialAuthController
{
    public function googleAuth(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'access_token' => Validator::required()->stringType(),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // Récupérer les informations utilisateur depuis Google API
            $accessToken = $data['access_token'];
            $userInfo = $this->getUserInfoFromGoogle($accessToken);
            
            if (!$userInfo) {
                return Response::unauthorized('Invalid Google access token');
            }

            $email = $userInfo['email'];
            $name = $userInfo['name'] ?? 'Google User';
            $picture = $userInfo['picture'] ?? null;
            
            // Diviser le nom complet
            $nameParts = explode(' ', trim($name), 2);
            $firstName = $nameParts[0];
            $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

            // Chercher l'utilisateur existant
            $user = User::where('email', $email)->first();

            $googleUserId = $userInfo['id'] ?? $userInfo['sub'] ?? substr(md5($email), 0, 10);

            if ($user) {
                // Utilisateur existant - mise à jour des infos sociales
                $user->social_provider = 'google';
                $user->social_id = $googleUserId;
                if (!$user->profile_picture && $picture) {
                    $user->profile_picture = $picture;
                }
                $user->last_login_at = Carbon::now();
                $user->save();
            } else {
                // Nouvel utilisateur - création
                $user = User::create([
                    'uuid' => \Ramsey\Uuid\Uuid::uuid4()->toString(),
                    'email' => $email,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'profile_picture' => $picture,
                    'social_provider' => 'google',
                    'social_id' => $googleUserId,
                    'email_verified_at' => Carbon::now(), // Les comptes Google sont déjà vérifiés
                    'last_login_at' => Carbon::now(),
                    'status' => 'active',
                    'role' => 'user',
                    'is_verified' => true,
                    'password_hash' => password_hash(uniqid(), PASSWORD_ARGON2ID), // Mot de passe factice pour SSO
                ]);
            }

            // Générer les tokens JWT
            $tokens = JWTHelper::generateTokens($user);

            // Enregistrer le token FCM si fourni
            $this->registerFCMTokenIfProvided($data, $user->id);

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'full_name' => $user->full_name,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'email_verified_at' => $user->email_verified_at,
                    'phone_verified_at' => $user->phone_verified_at,
                    'status' => $user->status,
                    'last_login_at' => $user->last_login_at,
                    'role' => $user->role,
                    'trust_score' => 0,
                    'completed_trips' => 0,
                    'total_trips' => 0,
                    'created_at' => $user->created_at,
                    'updated_at' => $user->updated_at,
                ],
                'tokens' => [
                    'access_token' => $tokens['access_token'],
                    'refresh_token' => $tokens['refresh_token'],
                    'token_type' => $tokens['token_type'],
                    'expires_in' => $tokens['expires_in'],
                ]
            ], 'Google authentication successful');

        } catch (\Exception $e) {
            return Response::serverError('Google authentication failed: ' . $e->getMessage());
        }
    }

    public function appleAuth(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        // Debug: Log les données reçues
        error_log("Apple Auth - Data received: " . json_encode($data));

        $validator = new Validator();
        $rules = [
            'identity_token' => Validator::required()->stringType(),
            'email' => Validator::optional(Validator::email()),
            'name' => Validator::optional(Validator::stringType()),
            'user_identifier' => Validator::required()->stringType(),
        ];

        if (!$validator->validate($data, $rules)) {
            error_log("Apple Auth - Validation errors: " . json_encode($validator->getErrors()));
            return Response::validationError($validator->getErrors());
        }

        error_log("Apple Auth - Validation passed, processing...");

        try {
            // TODO: Vérifier le token Apple avec l'API Apple
            // Pour l'instant, on fait confiance au token fourni par Flutter

            $userIdentifier = $data['user_identifier'];
            $email = $data['email'] ?? null;
            $name = $data['name'] ?? null;

            // Chercher l'utilisateur existant par social_id (Apple ID)
            $user = User::where('social_provider', 'apple')
                       ->where('social_id', $userIdentifier)
                       ->first();

            // Si pas trouvé par social_id et email fourni, chercher par email
            if (!$user && $email) {
                $user = User::where('email', $email)->first();
            }

            if ($user) {
                // Utilisateur existant
                $user->social_provider = 'apple';
                $user->social_id = $userIdentifier;
                $user->last_login_at = Carbon::now();
                $user->save();
            } else {
                // Nouvel utilisateur
                if (!$email) {
                    error_log("Apple Auth - No email provided for new user");
                    return Response::error('Email is required for new Apple Sign In users');
                }

                error_log("Apple Auth - Creating new user with email: " . $email);

                $nameParts = $name ? explode(' ', trim($name), 2) : ['Apple', 'User'];
                $firstName = $nameParts[0];
                $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

                $user = User::create([
                    'uuid' => \Ramsey\Uuid\Uuid::uuid4()->toString(),
                    'email' => $email,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'social_provider' => 'apple',
                    'social_id' => $userIdentifier,
                    'email_verified_at' => Carbon::now(), // Les comptes Apple sont déjà vérifiés
                    'last_login_at' => Carbon::now(),
                    'status' => 'active',
                    'role' => 'user',
                    'is_verified' => true,
                    'password_hash' => password_hash(uniqid(), PASSWORD_ARGON2ID), // Mot de passe factice pour SSO
                ]);
            }

            // Générer les tokens JWT
            $tokens = JWTHelper::generateTokens($user);

            // Enregistrer le token FCM si fourni
            $this->registerFCMTokenIfProvided($data, $user->id);

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'full_name' => $user->full_name,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'email_verified_at' => $user->email_verified_at,
                    'phone_verified_at' => $user->phone_verified_at,
                    'status' => $user->status,
                    'last_login_at' => $user->last_login_at,
                    'role' => $user->role,
                    'trust_score' => 0,
                    'completed_trips' => 0,
                    'total_trips' => 0,
                    'created_at' => $user->created_at,
                    'updated_at' => $user->updated_at,
                ],
                'tokens' => [
                    'access_token' => $tokens['access_token'],
                    'refresh_token' => $tokens['refresh_token'],
                    'token_type' => $tokens['token_type'],
                    'expires_in' => $tokens['expires_in'],
                ]
            ], 'Apple authentication successful');

        } catch (\Exception $e) {
            error_log("Apple Auth - Exception: " . $e->getMessage());
            error_log("Apple Auth - Stack trace: " . $e->getTraceAsString());
            return Response::serverError('Apple authentication failed: ' . $e->getMessage());
        }
    }


    /**
     * Récupérer les informations utilisateur depuis Google API
     */
    private function getUserInfoFromGoogle(string $accessToken): ?array
    {
        try {
            $url = "https://www.googleapis.com/oauth2/v2/userinfo?access_token=" . urlencode($accessToken);
            
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 10);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            
            if ($httpCode !== 200 || !$response) {
                return null;
            }
            
            $userInfo = json_decode($response, true);
            
            if (!$userInfo || !isset($userInfo['email'])) {
                return null;
            }
            
            return $userInfo;
            
        } catch (\Exception $e) {
            return null;
        }
    }

    /**
     * Enregistrer le token FCM si fourni dans les données
     */
    private function registerFCMTokenIfProvided(array $data, int $userId): void
    {
        if (!empty($data['fcm_token']) && !empty($data['platform'])) {
            try {
                $firebaseService = new FirebaseNotificationService();
                $firebaseService->registerToken(
                    $userId, 
                    $data['fcm_token'], 
                    $data['platform'] ?? 'mobile'
                );
            } catch (\Exception $e) {
                // Log l'erreur mais ne pas faire échouer l'authentification
                error_log("Erreur enregistrement FCM token lors de l'auth SSO: " . $e->getMessage());
            }
        }
    }
}