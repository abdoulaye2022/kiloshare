<?php

declare(strict_types=1);

namespace KiloShare\Modules\Auth\Controllers;

use KiloShare\Modules\Auth\Services\AuthService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Respect\Validation\Validator as v;
use Respect\Validation\Exceptions\ValidationException;

class AuthController
{
    private AuthService $authService;

    public function __construct(AuthService $authService)
    {
        $this->authService = $authService;
    }

    public function register(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Validate input
            $this->validateRegistrationInput($data);
            
            // Register user
            $result = $this->authService->register($data);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'User registered successfully',
                'data' => $result
            ]));
            
            return $response
                ->withStatus(201)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'REGISTRATION_FAILED'
            ]));
            
            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Registration failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function login(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            // Validate input
            if (empty($data['email']) || empty($data['password'])) {
                throw new \RuntimeException('Email and password are required', 400);
            }
            
            // Login user
            $result = $this->authService->login($data['email'], $data['password']);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Login successful',
                'data' => $result
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'LOGIN_FAILED'
            ]));
            
            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Login failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function refreshToken(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (empty($data['refresh_token'])) {
                throw new \RuntimeException('Refresh token is required', 400);
            }
            
            // Refresh token
            $result = $this->authService->refreshToken($data['refresh_token']);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Token refreshed successfully',
                'data' => $result
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'TOKEN_REFRESH_FAILED'
            ]));
            
            return $response
                ->withStatus(401)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Token refresh failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function verifyPhone(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody();
            
            if (empty($data['code'])) {
                throw new \RuntimeException('Verification code is required', 400);
            }
            
            if (strlen($data['code']) !== 6 || !is_numeric($data['code'])) {
                throw new \RuntimeException('Invalid verification code format', 400);
            }
            
            // Verify phone
            $success = $this->authService->verifyPhone($user['id'], $data['code']);
            
            if (!$success) {
                throw new \RuntimeException('Invalid or expired verification code', 400);
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Phone verified successfully'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'PHONE_VERIFICATION_FAILED'
            ]));
            
            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Phone verification failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function forgotPassword(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (empty($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
                throw new \RuntimeException('Valid email is required', 400);
            }
            
            // Request password reset
            $this->authService->forgotPassword($data['email']);
            
            // Always return success to prevent email enumeration
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'If the email exists, a password reset link has been sent'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Password reset request failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function resetPassword(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (empty($data['token']) || empty($data['password'])) {
                throw new \RuntimeException('Token and new password are required', 400);
            }
            
            if (strlen($data['password']) < 8) {
                throw new \RuntimeException('Password must be at least 8 characters', 400);
            }
            
            // Reset password
            $success = $this->authService->resetPassword($data['token'], $data['password']);
            
            if (!$success) {
                throw new \RuntimeException('Password reset failed', 500);
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Password reset successfully'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'PASSWORD_RESET_FAILED'
            ]));
            
            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Password reset failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function logout(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (empty($data['refresh_token'])) {
                throw new \RuntimeException('Refresh token is required', 400);
            }
            
            // Logout user
            $this->authService->logout($data['refresh_token']);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Logged out successfully'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Logged out successfully'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function me(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => ['user' => $user]
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to get user data',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    private function validateRegistrationInput(array $data): void
    {
        if (empty($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            throw new \RuntimeException('Valid email is required', 400);
        }

        if (empty($data['password']) || strlen($data['password']) < 8) {
            throw new \RuntimeException('Password must be at least 8 characters', 400);
        }

        if (!empty($data['first_name']) && (strlen($data['first_name']) < 1 || strlen($data['first_name']) > 100)) {
            throw new \RuntimeException('First name must be 1-100 characters', 400);
        }

        if (!empty($data['last_name']) && (strlen($data['last_name']) < 1 || strlen($data['last_name']) > 100)) {
            throw new \RuntimeException('Last name must be 1-100 characters', 400);
        }

        if (!empty($data['phone'])) {
            // Basic phone validation - you might want to use a more sophisticated library
            if (!preg_match('/^\+?[1-9]\d{1,14}$/', $data['phone'])) {
                throw new \RuntimeException('Invalid phone number format', 400);
            }
        }
    }

    private function getStatusCodeFromMessage(string $message): int
    {
        if (str_contains($message, 'already exists')) {
            return 409; // Conflict
        }

        if (str_contains($message, 'Invalid credentials') || str_contains($message, 'expired')) {
            return 401; // Unauthorized
        }

        if (str_contains($message, 'not active')) {
            return 403; // Forbidden
        }

        if (str_contains($message, 'required') || str_contains($message, 'Invalid')) {
            return 400; // Bad Request
        }

        return 500; // Internal Server Error
    }
}