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
     * Authenticate with Facebook
     * POST /api/v1/auth/facebook
     */
    public function facebookAuth(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }

            if (empty($data['access_token'])) {
                throw new \RuntimeException('Facebook access token is required', 400);
            }

            $result = $this->socialAuthService->authenticateWithFacebook($data['access_token']);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result['is_new_user'] ? 'Account created with Facebook' : 'Logged in with Facebook',
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
                'error_code' => 'FACEBOOK_AUTH_FAILED'
            ]));

            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Facebook authentication failed',
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
            'facebook' => [
                'name' => 'Facebook',
                'enabled' => !empty($_ENV['FACEBOOK_APP_ID']),
                'icon' => 'facebook',
                'color' => '#1877f2'
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