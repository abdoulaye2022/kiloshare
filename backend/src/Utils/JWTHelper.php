<?php

declare(strict_types=1);

namespace KiloShare\Utils;

use Firebase\JWT\JWT;
use KiloShare\Models\User;

class JWTHelper
{
    private static array $config;

    private static function getConfig(): array
    {
        if (!isset(self::$config)) {
            $settings = require __DIR__ . '/../../config/settings.php';
            self::$config = $settings['jwt'];
        }
        return self::$config;
    }

    public static function generateAccessToken(User $user): string
    {
        $config = self::getConfig();
        $now = time();
        $expiry = $now + $config['access_token_expiry'];

        $payload = [
            'iss' => $config['issuer'],
            'aud' => $config['audience'],
            'iat' => $now,
            'nbf' => $now,
            'exp' => $expiry,
            'sub' => $user->id,
            'user_id' => $user->id,
            'email' => $user->email,
            'role' => $user->role,
            'type' => 'access'
        ];

        return JWT::encode($payload, $config['secret'], $config['algorithm']);
    }

    public static function generateRefreshToken(User $user): string
    {
        $config = self::getConfig();
        $now = time();
        $expiry = $now + $config['refresh_token_expiry'];

        $payload = [
            'iss' => $config['issuer'],
            'aud' => $config['audience'],
            'iat' => $now,
            'nbf' => $now,
            'exp' => $expiry,
            'sub' => $user->id,
            'user_id' => $user->id,
            'type' => 'refresh',
            'jti' => \Ramsey\Uuid\Uuid::uuid4()->toString()
        ];

        return JWT::encode($payload, $config['secret'], $config['algorithm']);
    }

    public static function generateTokens(User $user): array
    {
        $config = self::getConfig();
        
        return [
            'access_token' => self::generateAccessToken($user),
            'refresh_token' => self::generateRefreshToken($user),
            'token_type' => 'bearer',
            'expires_in' => $config['access_token_expiry'],
        ];
    }

    public static function validateToken(string $token): ?array
    {
        try {
            $config = self::getConfig();
            $decoded = JWT::decode($token, $config['secret'], [$config['algorithm']]);
            return (array) $decoded;
        } catch (\Exception $e) {
            return null;
        }
    }

    public static function getUserFromToken(string $token): ?User
    {
        $payload = self::validateToken($token);
        
        if (!$payload || !isset($payload['user_id'])) {
            return null;
        }

        return User::find($payload['user_id']);
    }
}