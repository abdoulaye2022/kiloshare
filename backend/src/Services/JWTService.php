<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\SignatureInvalidException;
use Firebase\JWT\BeforeValidException;

class JWTService
{
    private string $secretKey;
    private string $algorithm;
    private int $accessTokenExpiry;
    private int $refreshTokenExpiry;

    public function __construct(array $settings)
    {
        $this->secretKey = $settings['jwt']['secret'];
        $this->algorithm = $settings['jwt']['algorithm'] ?? 'HS256';
        $this->accessTokenExpiry = $settings['jwt']['access_expires_in'] ?? 3600; // 1 hour
        $this->refreshTokenExpiry = $settings['jwt']['refresh_expires_in'] ?? 604800; // 7 days
    }

    public function generateAccessToken(array $user): string
    {
        $now = time();
        $payload = [
            'iss' => 'kiloshare-api',
            'aud' => 'kiloshare-app',
            'iat' => $now,
            'exp' => $now + $this->accessTokenExpiry,
            'sub' => $user['uuid'],
            'user' => [
                'id' => $user['id'],
                'uuid' => $user['uuid'],
                'email' => $user['email'],
                'phone' => $user['phone'] ?? null,
                'first_name' => $user['first_name'] ?? null,
                'last_name' => $user['last_name'] ?? null,
                'is_verified' => (bool)$user['is_verified'],
                'role' => $user['role'] ?? 'user'
            ],
            'type' => 'access'
        ];

        return JWT::encode($payload, $this->secretKey, $this->algorithm);
    }

    public function generateRefreshToken(array $user): string
    {
        $now = time();
        $payload = [
            'iss' => 'kiloshare-api',
            'aud' => 'kiloshare-app',
            'iat' => $now,
            'exp' => $now + $this->refreshTokenExpiry,
            'sub' => $user['uuid'],
            'user_id' => $user['id'],
            'type' => 'refresh'
        ];

        return JWT::encode($payload, $this->secretKey, $this->algorithm);
    }

    public function validateToken(string $token): ?array
    {
        try {
            $decoded = JWT::decode($token, new Key($this->secretKey, $this->algorithm));
            return (array) $decoded;
        } catch (ExpiredException $e) {
            throw new \RuntimeException('Token has expired', 401);
        } catch (SignatureInvalidException $e) {
            throw new \RuntimeException('Invalid token signature', 401);
        } catch (BeforeValidException $e) {
            throw new \RuntimeException('Token not yet valid', 401);
        } catch (\Exception $e) {
            throw new \RuntimeException('Invalid token: ' . $e->getMessage(), 401);
        }
    }

    public function refreshAccessToken(string $refreshToken): ?array
    {
        try {
            $decoded = $this->validateToken($refreshToken);
            
            if ($decoded['type'] !== 'refresh') {
                throw new \RuntimeException('Invalid token type', 400);
            }

            return [
                'user_id' => $decoded['user_id'],
                'uuid' => $decoded['sub']
            ];
        } catch (\Exception $e) {
            throw $e;
        }
    }

    public function getUserFromToken(string $token): ?array
    {
        try {
            $decoded = $this->validateToken($token);
            
            if ($decoded['type'] !== 'access') {
                throw new \RuntimeException('Invalid token type', 400);
            }

            return isset($decoded['user']) ? (array)$decoded['user'] : null;
        } catch (\Exception $e) {
            throw $e;
        }
    }

    public function generatePasswordResetToken(string $email): string
    {
        $now = time();
        $payload = [
            'iss' => 'kiloshare-api',
            'aud' => 'kiloshare-app',
            'iat' => $now,
            'exp' => $now + 3600, // 1 hour
            'email' => $email,
            'type' => 'password_reset'
        ];

        return JWT::encode($payload, $this->secretKey, $this->algorithm);
    }

    public function validatePasswordResetToken(string $token): ?string
    {
        try {
            $decoded = $this->validateToken($token);
            
            if ($decoded['type'] !== 'password_reset') {
                throw new \RuntimeException('Invalid token type', 400);
            }

            return $decoded['email'] ?? null;
        } catch (\Exception $e) {
            throw $e;
        }
    }

    public function getTokenExpiry(string $token): ?int
    {
        try {
            $decoded = $this->validateToken($token);
            return $decoded['exp'] ?? null;
        } catch (\Exception $e) {
            return null;
        }
    }

    public function isTokenExpired(string $token): bool
    {
        try {
            $this->validateToken($token);
            return false;
        } catch (\RuntimeException $e) {
            return str_contains($e->getMessage(), 'expired');
        }
    }
}