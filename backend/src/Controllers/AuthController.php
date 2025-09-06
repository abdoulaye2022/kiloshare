<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Firebase\JWT\JWT;
use KiloShare\Models\User;
use KiloShare\Models\UserToken;
use KiloShare\Models\EmailVerification;
use KiloShare\Services\EmailService;
use KiloShare\Services\FirebaseNotificationService;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Ramsey\Uuid\Uuid;
use Carbon\Carbon;

class AuthController
{
    private array $jwtConfig;

    public function __construct()
    {
        $settings = require __DIR__ . '/../../config/settings.php';
        $this->jwtConfig = $settings['jwt'];
    }

    public function register(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        // Validation des données
        $validator = new Validator();
        $rules = [
            'email' => Validator::required()->email(),
            'password' => Validator::password(),
            'first_name' => Validator::required()->stringType()->length(2, 50),
            'last_name' => Validator::required()->stringType()->length(2, 50),
            'phone' => Validator::optional(Validator::phone()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // Vérifier si l'email existe déjà
            if (User::withEmail($data['email'])->exists()) {
                return Response::error('Email already registered', [], 409);
            }

            // Vérifier si le téléphone existe déjà
            if (!empty($data['phone']) && User::withPhone($data['phone'])->exists()) {
                return Response::error('Phone number already registered', [], 409);
            }

            // Créer l'utilisateur
            $user = User::create([
                'uuid' => Uuid::uuid4()->toString(),
                'email' => $data['email'],
                'password_hash' => password_hash($data['password'], PASSWORD_ARGON2ID),
                'first_name' => $data['first_name'],
                'last_name' => $data['last_name'],
                'phone' => $data['phone'] ?? null,
                'status' => 'active',
                'role' => 'user',
            ]);

            // Générer les tokens
            $tokens = $this->generateTokens($user);

            // Stocker le refresh token
            UserToken::create([
                'user_id' => $user->id,
                'token' => $tokens['refresh_token'],
                'type' => 'refresh',
                'expires_at' => Carbon::now()->addSeconds($this->jwtConfig['refresh_token_expiry']),
            ]);

            // Créer une vérification d'email et envoyer l'email
            try {
                $emailVerification = EmailVerification::createForUser($user->id);
                $emailService = new EmailService();
                
                $userName = $user->first_name ? "{$user->first_name} {$user->last_name}" : $user->email;
                $emailSent = $emailService->sendEmailVerification(
                    $user->email,
                    $userName,
                    $emailVerification->code
                );
                
                $message = $emailSent 
                    ? 'User registered successfully. Please check your email to verify your account.'
                    : 'User registered successfully. Email verification failed to send.';
                
            } catch (\Exception $e) {
                error_log("Email verification failed for user {$user->id}: " . $e->getMessage());
                error_log("Stack trace: " . $e->getTraceAsString());
                $message = 'User registered successfully. Email verification service is temporarily unavailable.';
            }

            // Enregistrer le token FCM si fourni
            $this->registerFCMTokenIfProvided($data, $user->id);

            return Response::created([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'phone' => $user->phone,
                    'role' => $user->role,
                    'is_verified' => $user->is_verified,
                ],
                'tokens' => $tokens
            ], $message ?? 'User registered successfully');

        } catch (\Exception $e) {
            return Response::serverError('Registration failed: ' . $e->getMessage());
        }
    }

    public function verifyEmail(ServerRequestInterface $request): ResponseInterface
    {
        $queryParams = $request->getQueryParams();
        $code = $queryParams['code'] ?? '';

        if (empty($code)) {
            return Response::error('Verification code is required', [], 400);
        }

        try {
            $emailVerification = EmailVerification::findValidByCode($code);
            
            if (!$emailVerification) {
                return Response::error('Invalid or expired verification code', [], 400);
            }

            // Marquer l'email comme vérifié
            $emailVerification->markAsVerified();
            
            // Mettre à jour l'utilisateur
            $user = User::find($emailVerification->user_id);
            if ($user) {
                $user->update([
                    'email_verified_at' => Carbon::now(),
                    'is_verified' => true
                ]);
            }

            return Response::success([], 'Email verified successfully');

        } catch (\Exception $e) {
            return Response::serverError('Email verification failed: ' . $e->getMessage());
        }
    }

    public function login(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        // Validation
        $validator = new Validator();
        $rules = [
            'email' => Validator::required()->email(),
            'password' => Validator::required()->stringType(),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // Trouver l'utilisateur
            $user = User::withEmail($data['email'])->first();

            if (!$user || !password_verify($data['password'], $user->password_hash)) {
                return Response::unauthorized('Adresse e-mail ou mot de passe incorrect');
            }

            // Vérifier le statut
            if (!$user->isActive()) {
                return Response::unauthorized('Votre compte n\'est pas actif');
            }

            // Mettre à jour la dernière connexion
            $user->updateLastLogin();

            // Générer les tokens
            $tokens = $this->generateTokens($user);

            // Stocker le refresh token
            UserToken::create([
                'user_id' => $user->id,
                'token' => $tokens['refresh_token'],
                'type' => 'refresh',
                'expires_at' => Carbon::now()->addSeconds($this->jwtConfig['refresh_token_expiry']),
            ]);

            // Enregistrer le token FCM si fourni
            $this->registerFCMTokenIfProvided($data, $user->id);

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'phone' => $user->phone,
                    'role' => $user->role,
                    'is_verified' => $user->is_verified,
                ],
                'tokens' => $tokens
            ], 'Login successful');

        } catch (\Exception $e) {
            return Response::serverError('Login failed: ' . $e->getMessage());
        }
    }

    public function adminLogin(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        // Validation
        $validator = new Validator();
        $rules = [
            'email' => Validator::required()->email(),
            'password' => Validator::required()->stringType(),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // Trouver l'utilisateur admin
            $user = User::withEmail($data['email'])
                        ->where('role', 'admin')
                        ->first();

            if (!$user || !password_verify($data['password'], $user->password_hash)) {
                return Response::unauthorized('Identifiants administrateur incorrects');
            }

            if (!$user->isActive()) {
                return Response::unauthorized('Le compte administrateur n\'est pas actif');
            }

            // Mettre à jour la dernière connexion
            $user->updateLastLogin();

            // Générer les tokens
            $tokens = $this->generateTokens($user);

            // Stocker le refresh token
            UserToken::create([
                'user_id' => $user->id,
                'token' => $tokens['refresh_token'],
                'type' => 'refresh',
                'expires_at' => Carbon::now()->addSeconds($this->jwtConfig['refresh_token_expiry']),
            ]);

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'phone' => $user->phone,
                    'role' => $user->role,
                    'is_verified' => $user->is_verified,
                ],
                'tokens' => $tokens
            ], 'Admin login successful');

        } catch (\Exception $e) {
            return Response::serverError('Admin login failed: ' . $e->getMessage());
        }
    }

    public function me(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        return Response::success([
            'id' => $user->id,
            'uuid' => $user->uuid,
            'email' => $user->email,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'phone' => $user->phone,
            'role' => $user->role,
            'is_verified' => $user->is_verified,
            'email_verified_at' => $user->email_verified_at,
            'phone_verified_at' => $user->phone_verified_at,
            'created_at' => $user->created_at,
        ]);
    }

    public function refreshToken(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        if (empty($data['refresh_token'])) {
            return Response::error('Refresh token is required');
        }

        try {
            // Vérifier le refresh token
            $tokenRecord = UserToken::where('token', $data['refresh_token'])
                                   ->where('type', 'refresh')
                                   ->where('expires_at', '>', Carbon::now())
                                   ->first();

            if (!$tokenRecord) {
                return Response::unauthorized('Invalid refresh token');
            }

            $user = User::find($tokenRecord->user_id);
            if (!$user || !$user->isActive()) {
                return Response::unauthorized('User not found or inactive');
            }

            // Supprimer l'ancien refresh token
            $tokenRecord->delete();

            // Générer de nouveaux tokens
            $tokens = $this->generateTokens($user);

            // Stocker le nouveau refresh token
            UserToken::create([
                'user_id' => $user->id,
                'token' => $tokens['refresh_token'],
                'type' => 'refresh',
                'expires_at' => Carbon::now()->addSeconds($this->jwtConfig['refresh_token_expiry']),
            ]);

            return Response::success([
                'tokens' => $tokens
            ], 'Token refreshed successfully');

        } catch (\Exception $e) {
            return Response::serverError('Token refresh failed: ' . $e->getMessage());
        }
    }

    public function logout(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            // Supprimer tous les refresh tokens de l'utilisateur
            UserToken::where('user_id', $user->id)
                     ->where('type', 'refresh')
                     ->delete();

            return Response::success([], 'Logout successful');

        } catch (\Exception $e) {
            return Response::serverError('Logout failed: ' . $e->getMessage());
        }
    }

    private function generateTokens(User $user): array
    {
        $now = time();
        $accessTokenExpiry = $now + $this->jwtConfig['access_token_expiry'];
        $refreshTokenExpiry = $now + $this->jwtConfig['refresh_token_expiry'];

        // Access token payload
        $accessPayload = [
            'iss' => $this->jwtConfig['issuer'],
            'aud' => $this->jwtConfig['audience'],
            'iat' => $now,
            'exp' => $accessTokenExpiry,
            'sub' => $user->uuid,
            'user' => [
                'id' => $user->id,
                'uuid' => $user->uuid,
                'email' => $user->email,
                'phone' => $user->phone,
                'first_name' => $user->first_name,
                'last_name' => $user->last_name,
                'is_verified' => $user->is_verified,
                'role' => $user->role,
            ],
            'type' => 'access'
        ];

        // Refresh token payload
        $refreshPayload = [
            'iss' => $this->jwtConfig['issuer'],
            'aud' => $this->jwtConfig['audience'],
            'iat' => $now,
            'exp' => $refreshTokenExpiry,
            'sub' => $user->uuid,
            'user_id' => $user->id,
            'type' => 'refresh'
        ];

        return [
            'access_token' => JWT::encode($accessPayload, $this->jwtConfig['secret'], $this->jwtConfig['algorithm']),
            'refresh_token' => JWT::encode($refreshPayload, $this->jwtConfig['secret'], $this->jwtConfig['algorithm']),
            'token_type' => 'bearer',
            'expires_in' => $this->jwtConfig['access_token_expiry'],
        ];
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
                error_log("Erreur enregistrement FCM token lors de l'auth: " . $e->getMessage());
            }
        }
    }
}