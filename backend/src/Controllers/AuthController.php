<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Services\AuthService;
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
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
                error_log('Raw body: ' . $rawBody);
                error_log('Decoded data: ' . json_encode($data));
            }
            
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
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
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

    public function refresh(Request $request, Response $response): Response
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
            error_log("AuthController: forgotPassword called");
            
            // Get request data with fallback
            $data = $request->getParsedBody();
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            error_log("AuthController: Request data: " . json_encode($data));
            
            if (empty($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
                error_log("AuthController: Invalid email provided");
                throw new \RuntimeException('Valid email is required', 400);
            }
            
            error_log("AuthController: Email valid, proceeding...");
            
            // Ensure we have authService
            if (!$this->authService) {
                error_log("AuthController: AuthService not injected!");
                throw new \RuntimeException('Service not available', 500);
            }
            
            error_log("AuthController: Calling authService->forgotPassword");
            
            // Request password reset with error handling
            $result = $this->authService->forgotPassword($data['email']);
            
            error_log("AuthController: forgotPassword completed successfully");
            
            // Always return success to prevent email enumeration
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'If the email exists, a password reset link has been sent'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            error_log("AuthController: Exception in forgotPassword: " . $e->getMessage());
            error_log("AuthController: Exception trace: " . $e->getTraceAsString());
            
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
            $data = $request->getParsedBody() ?? [];
            
            // Fallback: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            if (empty($data['token']) || empty($data['password'])) {
                throw new \RuntimeException('Token and new password are required', 400);
            }
            
            if (strlen($data['password']) < 6) {
                throw new \RuntimeException('Password must be at least 6 characters', 400);
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
            
            // Normalize user data for API
            $user = \KiloShare\Models\User::normalizeForApi($user);
            
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

    public function updateProfile(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody();
            
            // TODO: Implement profile update logic
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Profile update not implemented yet'
            ]));
            
            return $response
                ->withStatus(501)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Profile update failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function changePassword(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody();
            
            // TODO: Implement change password logic
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Change password not implemented yet'
            ]));
            
            return $response
                ->withStatus(501)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Change password failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    private function validateRegistrationInput(array $data): void
    {
        // Debug: Log received data
        error_log('=== Registration Debug ===');
        error_log('Received data: ' . json_encode($data));
        error_log('Email value: ' . ($data['email'] ?? 'NULL'));
        error_log('Email empty check: ' . (empty($data['email']) ? 'TRUE' : 'FALSE'));
        error_log('Email filter_var result: ' . (filter_var($data['email'] ?? '', FILTER_VALIDATE_EMAIL) ? 'VALID' : 'INVALID'));
        error_log('==========================');
        
        if (empty($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            throw new \RuntimeException('Valid email is required', 400);
        }

        if (empty($data['password']) || strlen($data['password']) < 6) {
            throw new \RuntimeException('Password must be at least 6 characters', 400);
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

    public function verifyEmail(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            if (empty($data['token'])) {
                throw new \RuntimeException('Verification token is required', 400);
            }
            
            // Verify email
            $success = $this->authService->verifyEmail($data['token']);
            
            if (!$success) {
                throw new \RuntimeException('Email verification failed', 500);
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Email verified successfully'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'EMAIL_VERIFICATION_FAILED'
            ]));
            
            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Email verification failed',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    public function resendEmailVerification(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            if (empty($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
                throw new \RuntimeException('Valid email is required', 400);
            }
            
            // Resend verification email
            $success = $this->authService->resendEmailVerification($data['email']);
            
            if (!$success) {
                throw new \RuntimeException('Failed to resend verification email', 500);
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Verification email sent successfully'
            ]));
            
            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\RuntimeException $e) {
            $statusCode = $this->getStatusCodeFromMessage($e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'EMAIL_RESEND_FAILED'
            ]));
            
            return $response
                ->withStatus($statusCode)
                ->withHeader('Content-Type', 'application/json');
                
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to resend verification email',
                'error_code' => 'INTERNAL_ERROR'
            ]));
            
            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }
}