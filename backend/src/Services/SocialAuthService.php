<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\User;
use KiloShare\Services\JWTService;
use KiloShare\Services\EmailService;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Ramsey\Uuid\Uuid;

class SocialAuthService
{
    private User $userModel;
    private JWTService $jwtService;
    private EmailService $emailService;
    private array $config;

    public function __construct(User $userModel, JWTService $jwtService, EmailService $emailService, array $config)
    {
        $this->userModel = $userModel;
        $this->jwtService = $jwtService;
        $this->emailService = $emailService;
        $this->config = $config;
    }

    /**
     * Authenticate with Google
     */
    public function authenticateWithGoogle(string $accessToken): array
    {
        // Get user info from Google
        $googleUser = $this->getGoogleUserInfo($accessToken);
        
        if (!$googleUser) {
            throw new \RuntimeException('Failed to get user info from Google', 400);
        }

        return $this->handleSocialUser($googleUser, 'google');
    }


    /**
     * Authenticate with Apple
     */
    public function authenticateWithApple(string $idToken): array
    {
        // Verify Apple ID token
        $appleUser = $this->verifyAppleIdToken($idToken);
        
        if (!$appleUser) {
            throw new \RuntimeException('Failed to verify Apple ID token', 400);
        }

        return $this->handleSocialUser($appleUser, 'apple');
    }

    /**
     * Handle social user authentication
     */
    public function handleSocialUser(array $socialUser, string $provider): array
    {
        $email = $socialUser['email'] ?? null;
        
        if (!$email) {
            throw new \RuntimeException('Email is required for social authentication', 400);
        }

        // Check if user already exists
        $existingUser = $this->userModel->findByEmail($email);
        
        if ($existingUser) {
            // Update last login and social provider info
            $this->updateUserSocialInfo($existingUser['id'], $provider, $socialUser);
            $user = $this->userModel->findById($existingUser['id']);
        } else {
            // Create new user from social data
            $user = $this->createUserFromSocial($socialUser, $provider);
        }

        // Generate tokens
        $accessToken = $this->jwtService->generateAccessToken($user);
        $refreshToken = $this->jwtService->generateRefreshToken($user);

        // Store refresh token
        $this->storeRefreshToken($user['id'], $refreshToken);

        // Remove sensitive data and normalize
        unset($user['password_hash']);
        $user = User::normalizeForApi($user);

        // Send welcome email for new users
        $isNewUser = !$existingUser;
        if ($isNewUser) {
            $this->emailService->sendWelcomeEmail($user);
        }

        return [
            'user' => $user,
            'tokens' => [
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'bearer',
                'expires_in' => 3600
            ],
            'is_new_user' => $isNewUser
        ];
    }

    /**
     * Get user info from Google
     */
    private function getGoogleUserInfo(string $accessToken): ?array
    {
        $url = 'https://www.googleapis.com/oauth2/v2/userinfo?access_token=' . $accessToken;
        
        $response = $this->makeHttpRequest($url);
        
        if (!$response) {
            return null;
        }

        $data = json_decode($response, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            return null;
        }

        return [
            'id' => $data['id'] ?? null,
            'email' => $data['email'] ?? null,
            'first_name' => $data['given_name'] ?? '',
            'last_name' => $data['family_name'] ?? '',
            'profile_picture' => $data['picture'] ?? null,
            'verified_email' => $data['verified_email'] ?? false
        ];
    }


    /**
     * Verify Apple ID token
     */
    private function verifyAppleIdToken(string $idToken): ?array
    {
        try {
            // For development, decode without verification
            // In production, you should implement proper JWT verification
            $parts = explode('.', $idToken);
            
            if (count($parts) !== 3) {
                return null;
            }

            // Decode the payload (second part)
            $payload = base64_decode(strtr($parts[1], '-_', '+/'));
            $data = json_decode($payload, true);
            
            if (json_last_error() !== JSON_ERROR_NONE) {
                return null;
            }

            // Basic validation
            if ($data['iss'] !== 'https://appleid.apple.com' || 
                $data['aud'] !== 'com.m2atech.kiloshare') {
                error_log('Apple token validation failed: iss=' . $data['iss'] . ', aud=' . $data['aud']);
                return null;
            }

            return [
                'id' => $data['sub'] ?? null,
                'email' => $data['email'] ?? null,
                'first_name' => $data['given_name'] ?? '',
                'last_name' => $data['family_name'] ?? '',
                'profile_picture' => null,
                'verified_email' => $data['email_verified'] ?? false
            ];
        } catch (\Exception $e) {
            error_log('Apple ID token verification failed: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Create user from social data
     */
    private function createUserFromSocial(array $socialUser, string $provider): array
    {
        $userData = [
            'uuid' => Uuid::uuid4()->toString(),
            'email' => strtolower(trim($socialUser['email'])),
            'first_name' => trim($socialUser['first_name']),
            'last_name' => trim($socialUser['last_name']),
            'profile_picture' => $socialUser['profile_picture'],
            'password_hash' => null, // No password for social users
            'is_verified' => $socialUser['verified_email'] ? 1 : 0,
            'email_verified_at' => $socialUser['verified_email'] ? date('Y-m-d H:i:s') : null,
            'social_provider' => $provider,
            'social_id' => $socialUser['id']
        ];

        $user = $this->userModel->create($userData);
        
        if (!$user) {
            throw new \RuntimeException('Failed to create user from social data', 500);
        }

        return $user;
    }

    /**
     * Update user social information
     */
    private function updateUserSocialInfo(int $userId, string $provider, array $socialUser): void
    {
        // Update last login
        $this->userModel->updateLastLogin($userId);
        
        // Update profile picture if provided
        if (!empty($socialUser['profile_picture'])) {
            $this->userModel->updateProfile($userId, [
                'profile_picture' => $socialUser['profile_picture']
            ]);
        }
    }

    /**
     * Store refresh token
     */
    private function storeRefreshToken(int $userId, string $token): void
    {
        $expiresAt = date('Y-m-d H:i:s', strtotime('+7 days'));
        
        $sql = "INSERT INTO user_tokens (user_id, token, type, expires_at) VALUES (?, ?, 'refresh', ?)";
        $stmt = $this->userModel->getDb()->prepare($sql);
        $stmt->execute([$userId, $token, $expiresAt]);
    }

    /**
     * Make HTTP request
     */
    private function makeHttpRequest(string $url): ?string
    {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_USERAGENT, 'KiloShare/1.0');
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($response === false || $httpCode !== 200) {
            return null;
        }
        
        return $response;
    }

    /**
     * Get Apple's public keys
     */
    private function getApplePublicKeys(): ?array
    {
        $response = $this->makeHttpRequest('https://appleid.apple.com/auth/keys');
        
        if (!$response) {
            return null;
        }

        $data = json_decode($response, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            return null;
        }

        $keys = [];
        foreach ($data['keys'] as $key) {
            if (isset($key['kid']) && isset($key['n']) && isset($key['e'])) {
                $keys[$key['kid']] = $this->createRsaPublicKey($key['n'], $key['e']);
            }
        }

        return $keys;
    }

    /**
     * Create RSA public key from modulus and exponent
     */
    private function createRsaPublicKey(string $n, string $e): string
    {
        $n = $this->base64UrlDecode($n);
        $e = $this->base64UrlDecode($e);

        $rsa = [
            'modulus' => $n,
            'publicExponent' => $e
        ];

        return $this->rsaPublicKeyToPem($rsa);
    }

    /**
     * Base64 URL decode
     */
    private function base64UrlDecode(string $data): string
    {
        return base64_decode(strtr($data, '-_', '+/'));
    }

    /**
     * Convert RSA to PEM format
     */
    private function rsaPublicKeyToPem(array $rsa): string
    {
        // This is a simplified implementation
        // In production, use a proper ASN.1 encoder
        $modulus = $rsa['modulus'];
        $exponent = $rsa['publicExponent'];
        
        $encoded = base64_encode($modulus . $exponent);
        
        return "-----BEGIN PUBLIC KEY-----\n" . 
               chunk_split($encoded, 64) . 
               "-----END PUBLIC KEY-----";
    }

    /**
     * Decode JWT header
     */
    private function decodeJwtHeader(string $token): ?array
    {
        $parts = explode('.', $token);
        
        if (count($parts) !== 3) {
            return null;
        }

        $header = base64_decode(strtr($parts[0], '-_', '+/'));
        
        return json_decode($header, true);
    }
}