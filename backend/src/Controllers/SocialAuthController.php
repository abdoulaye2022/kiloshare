<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Services\SocialAuthService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class SocialAuthController
{
    private SocialAuthService $socialAuthService;

    public function __construct(SocialAuthService $socialAuthService)
    {
        $this->socialAuthService = $socialAuthService;
    }

    /**
     * Authenticate with Google
     * POST /api/v1/auth/google
     */
    public function googleAuth(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }

            if (empty($data['access_token'])) {
                throw new \RuntimeException('Google access token is required', 400);
            }

            $result = $this->socialAuthService->authenticateWithGoogle($data['access_token']);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result['is_new_user'] ? 'Account created with Google' : 'Logged in with Google',
                'data' => [
                    'user' => $result['user'],
                    'tokens' => $result['tokens'],
                    'is_new_user' => $result['is_new_user']
                ]
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'GOOGLE_AUTH_FAILED'
            ]));

            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Google authentication failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }


    /**
     * Authenticate with Firebase (Google, Apple, etc.)
     * POST /api/v1/auth/firebase
     */
    public function firebaseAuth(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }

            if (empty($data['firebase_token'])) {
                throw new \RuntimeException('Firebase token is required', 400);
            }

            // For now, simulate Firebase token verification
            // In production, use Firebase Admin SDK to verify the token
            $firebaseToken = $data['firebase_token'];
            
            // Mock user data from Firebase token
            $mockUser = [
                'id' => 'firebase_user_123',
                'email' => 'user@example.com',
                'first_name' => 'Firebase',
                'last_name' => 'User',
                'profile_picture' => null,
                'verified_email' => true
            ];

            // Simplified Firebase auth - just return mock success for now
            $result = [
                'user' => [
                    'id' => 'firebase_123',
                    'email' => 'firebase.user@example.com',
                    'first_name' => 'Firebase',
                    'last_name' => 'User',
                    'is_verified' => true
                ],
                'tokens' => [
                    'access_token' => 'mock_access_token_firebase',
                    'refresh_token' => 'mock_refresh_token_firebase',
                    'token_type' => 'bearer',
                    'expires_in' => 3600
                ],
                'is_new_user' => false
            ];

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result['is_new_user'] ? 'Account created with Firebase' : 'Logged in with Firebase',
                'data' => [
                    'user' => $result['user'],
                    'tokens' => $result['tokens'],
                    'is_new_user' => $result['is_new_user']
                ]
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'FIREBASE_AUTH_FAILED'
            ]));

            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Firebase authentication failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Authenticate with Apple
     * POST /api/v1/auth/apple
     */
    public function appleAuth(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }

            if (empty($data['id_token'])) {
                throw new \RuntimeException('Apple ID token is required', 400);
            }

            $result = $this->socialAuthService->authenticateWithApple($data['id_token']);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result['is_new_user'] ? 'Account created with Apple' : 'Logged in with Apple',
                'data' => [
                    'user' => $result['user'],
                    'tokens' => $result['tokens'],
                    'is_new_user' => $result['is_new_user']
                ]
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'APPLE_AUTH_FAILED'
            ]));

            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Apple authentication failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Get available social providers
     * GET /api/v1/auth/social/providers
     */
    public function getProviders(Request $request, Response $response): Response
    {
        $providers = [
            'google' => [
                'name' => 'Google',
                'enabled' => !empty($_ENV['GOOGLE_CLIENT_ID']),
                'icon' => 'google',
                'color' => '#4285f4'
            ],
            'apple' => [
                'name' => 'Apple',
                'enabled' => !empty($_ENV['APPLE_CLIENT_ID']),
                'icon' => 'apple',
                'color' => '#000000'
            ]
        ];

        $response->getBody()->write(json_encode([
            'success' => true,
            'data' => [
                'providers' => array_filter($providers, fn($provider) => $provider['enabled'])
            ]
        ]));

        return $response
            ->withStatus(200)
            ->withHeader('Content-Type', 'application/json');
    }

    /**
     * Link social account to existing user
     * POST /api/v1/auth/social/link
     */
    public function linkSocialAccount(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody() ?? [];

            if (empty($data['provider']) || empty($data['access_token'])) {
                throw new \RuntimeException('Provider and access token are required', 400);
            }

            // This would link a social account to existing user
            // Implementation depends on your database schema
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Social account linked successfully'
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'SOCIAL_LINK_FAILED'
            ]));

            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to link social account',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Unlink social account
     * DELETE /api/v1/auth/social/unlink/{provider}
     */
    public function unlinkSocialAccount(Request $request, Response $response, array $args): Response
    {
        try {
            $user = $request->getAttribute('user');
            $provider = $args['provider'] ?? '';

            if (empty($provider)) {
                throw new \RuntimeException('Provider is required', 400);
            }

            // This would unlink a social account from user
            // Implementation depends on your database schema
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Social account unlinked successfully'
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'SOCIAL_UNLINK_FAILED'
            ]));

            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to unlink social account',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    private function getStatusCodeFromMessage(string $message): int
    {
        if (str_contains($message, 'required') || str_contains($message, 'Invalid')) {
            return 400; // Bad Request
        }

        if (str_contains($message, 'unauthorized') || str_contains($message, 'token')) {
            return 401; // Unauthorized
        }

        if (str_contains($message, 'not found')) {
            return 404; // Not Found
        }

        return 500; // Internal Server Error
    }
}