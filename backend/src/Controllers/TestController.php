<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Services\EmailService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class TestController
{
    private EmailService $emailService;

    public function __construct(EmailService $emailService)
    {
        $this->emailService = $emailService;
    }

    /**
     * Test welcome email
     * POST /api/v1/test/email/welcome
     */
    public function testWelcomeEmail(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            if (empty($data['email'])) {
                throw new \RuntimeException('Email is required', 400);
            }

            $testUser = [
                'id' => 999,
                'email' => $data['email'],
                'first_name' => $data['first_name'] ?? 'Test',
                'last_name' => $data['last_name'] ?? 'User',
                'uuid' => 'test-uuid-' . time()
            ];

            $result = $this->emailService->sendWelcomeEmail($testUser);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result ? 'Welcome email sent successfully' : 'Failed to send welcome email (check API key configuration)',
                'data' => [
                    'email_sent' => $result,
                    'recipient' => $testUser['email'],
                    'test_mode' => true
                ]
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'TEST_EMAIL_FAILED'
            ]));

            return $response
                ->withStatus(400)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to send test email',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Test verification email
     * POST /api/v1/test/email/verification
     */
    public function testVerificationEmail(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            // Debug: Also try raw body if parsed body is empty
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            if (empty($data['email'])) {
                throw new \RuntimeException('Email is required', 400);
            }

            $testUser = [
                'id' => 999,
                'email' => $data['email'],
                'first_name' => $data['first_name'] ?? 'Test',
                'last_name' => $data['last_name'] ?? 'User',
                'uuid' => 'test-uuid-' . time()
            ];

            $testToken = 'test-verification-token-' . time();
            $result = $this->emailService->sendVerificationEmail($testUser, $testToken);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result ? 'Verification email sent successfully' : 'Failed to send verification email (check API key configuration)',
                'data' => [
                    'email_sent' => $result,
                    'recipient' => $testUser['email'],
                    'test_mode' => true
                ]
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'TEST_EMAIL_FAILED'
            ]));

            return $response
                ->withStatus(400)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to send test email',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Test password reset email
     * POST /api/v1/test/email/reset-password
     */
    public function testPasswordResetEmail(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody() ?? [];
            
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }
            
            if (empty($data['email'])) {
                throw new \RuntimeException('Email is required', 400);
            }

            $testUser = [
                'id' => 999,
                'email' => $data['email'],
                'first_name' => $data['first_name'] ?? 'Test',
                'last_name' => $data['last_name'] ?? 'User',
                'uuid' => 'test-uuid-' . time()
            ];

            $testToken = 'test-reset-token-' . time();
            $result = $this->emailService->sendPasswordResetEmail($testUser, $testToken);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => $result ? 'Password reset email sent successfully' : 'Failed to send password reset email (check API key configuration)',
                'data' => [
                    'email_sent' => $result,
                    'recipient' => $testUser['email'],
                    'test_mode' => true,
                    'reset_token' => $testToken
                ]
            ]));

            return $response
                ->withStatus(200)
                ->withHeader('Content-Type', 'application/json');

        } catch (\RuntimeException $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage(),
                'error_code' => 'TEST_EMAIL_FAILED'
            ]));

            return $response
                ->withStatus(400)
                ->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Failed to send test email',
                'error_code' => 'INTERNAL_ERROR'
            ]));

            return $response
                ->withStatus(500)
                ->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Get email configuration status
     * GET /api/v1/test/email/config
     */
    public function getEmailConfig(Request $request, Response $response): Response
    {
        $brevoApiKey = $_ENV['BREVO_API_KEY'] ?? '';
        $fromEmail = $_ENV['MAIL_FROM_ADDRESS'] ?? 'noreply@kiloshare.com';
        $fromName = $_ENV['MAIL_FROM_NAME'] ?? 'KiloShare';

        $response->getBody()->write(json_encode([
            'success' => true,
            'data' => [
                'brevo_api_key_configured' => !empty($brevoApiKey) && $brevoApiKey !== 'your-brevo-api-key-here',
                'from_email' => $fromEmail,
                'from_name' => $fromName,
                'email_service_enabled' => true
            ]
        ]));

        return $response
            ->withStatus(200)
            ->withHeader('Content-Type', 'application/json');
    }
}