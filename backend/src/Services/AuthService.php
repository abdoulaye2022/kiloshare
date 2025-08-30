<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\User;
use KiloShare\Models\EmailVerification;
use KiloShare\Services\JWTService;
use KiloShare\Services\EmailService;
use KiloShare\Services\MailSender;
use Ramsey\Uuid\Uuid;
use PDO;

class AuthService
{
    private User $userModel;
    private EmailVerification $emailVerificationModel;
    private JWTService $jwtService;
    private EmailService $emailService;
    private PDO $db;

    public function __construct(User $userModel, JWTService $jwtService, EmailService $emailService, PDO $db)
    {
        $this->userModel = $userModel;
        $this->emailVerificationModel = new EmailVerification($db);
        $this->jwtService = $jwtService;
        $this->emailService = $emailService;
        $this->db = $db;
    }

    public function register(array $data): array
    {
        // Validate input
        $this->validateRegistrationData($data);

        // Check if user already exists
        if ($this->userModel->emailExists($data['email'])) {
            throw new \RuntimeException('Email already exists', 409);
        }

        if (!empty($data['phone']) && $this->userModel->phoneExists($data['phone'])) {
            throw new \RuntimeException('Phone number already exists', 409);
        }

        // Hash password
        $passwordHash = password_hash($data['password'], PASSWORD_ARGON2ID);

        // Create user
        $userData = [
            'uuid' => Uuid::uuid4()->toString(),
            'email' => strtolower(trim($data['email'])),
            'phone' => !empty($data['phone']) ? trim($data['phone']) : null,
            'password_hash' => $passwordHash,
            'first_name' => trim($data['first_name'] ?? ''),
            'last_name' => trim($data['last_name'] ?? '')
        ];

        $user = $this->userModel->create($userData);

        if (!$user) {
            throw new \RuntimeException('Failed to create user', 500);
        }

        // Generate verification code if phone provided
        if (!empty($userData['phone'])) {
            $this->generateVerificationCode($user['id'], 'phone_verification');
        }

        // Send welcome email
        $this->emailService->sendWelcomeEmail($user);

        // Send email verification
        $this->sendEmailVerification($user);

        // Generate tokens
        $accessToken = $this->jwtService->generateAccessToken($user);
        $refreshToken = $this->jwtService->generateRefreshToken($user);

        // Store refresh token
        $this->storeRefreshToken($user['id'], $refreshToken);

        // Remove sensitive data
        unset($user['password_hash']);
        
        // Normalize user data for API
        $user = \KiloShare\Models\User::normalizeForApi($user);

        return [
            'user' => $user,
            'tokens' => [
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'bearer',
                'expires_in' => 3600
            ]
        ];
    }

    public function login(string $email, string $password): array
    {
        // Track login attempt
        $this->trackLoginAttempt($email, false);

        // Find user
        $user = $this->userModel->findByEmail(strtolower(trim($email)));

        if (!$user || !password_verify($password, $user['password_hash'])) {
            throw new \RuntimeException('Invalid credentials', 401);
        }

        // Check account status
        if ($user['status'] !== 'active') {
            throw new \RuntimeException('Account is not active', 403);
        }

        // Update last login
        $this->userModel->updateLastLogin($user['id']);

        // Track successful login
        $this->trackLoginAttempt($email, true);

        // Generate tokens
        $accessToken = $this->jwtService->generateAccessToken($user);
        $refreshToken = $this->jwtService->generateRefreshToken($user);

        // Store refresh token
        $this->storeRefreshToken($user['id'], $refreshToken);

        // Remove sensitive data
        unset($user['password_hash']);
        
        // Normalize user data for API
        $user = \KiloShare\Models\User::normalizeForApi($user);

        return [
            'user' => $user,
            'tokens' => [
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'bearer',
                'expires_in' => 3600
            ]
        ];
    }

    public function refreshToken(string $refreshToken): array
    {
        try {
            $tokenData = $this->jwtService->refreshAccessToken($refreshToken);
            
            // Validate refresh token in database
            if (!$this->validateRefreshToken($tokenData['user_id'], $refreshToken)) {
                throw new \RuntimeException('Invalid refresh token', 401);
            }

            // Get user
            $user = $this->userModel->findById($tokenData['user_id']);
            
            if (!$user || $user['status'] !== 'active') {
                throw new \RuntimeException('User not found or inactive', 401);
            }

            // Generate new access token
            $newAccessToken = $this->jwtService->generateAccessToken($user);

            // Remove sensitive data
            unset($user['password_hash']);
            
            // Normalize user data for API
            $user = \KiloShare\Models\User::normalizeForApi($user);

            return [
                'user' => $user,
                'tokens' => [
                    'access_token' => $newAccessToken,
                    'token_type' => 'bearer',
                    'expires_in' => 3600
                ]
            ];
        } catch (\Exception $e) {
            throw new \RuntimeException('Failed to refresh token: ' . $e->getMessage(), 401);
        }
    }

    public function verifyPhone(int $userId, string $code): bool
    {
        if ($this->validateVerificationCode($userId, $code, 'phone_verification')) {
            return $this->userModel->verifyPhone($userId);
        }
        
        return false;
    }

    public function forgotPassword(string $email): bool
    {
        try {
            error_log("ForgotPassword: Starting process for email {$email}");
            
            $user = $this->userModel->findByEmail(strtolower(trim($email)));
            
            if (!$user) {
                error_log("ForgotPassword: User not found for email {$email}");
                // Don't reveal if email exists or not
                return true;
            }

            error_log("ForgotPassword: User found, generating reset token");
            
            // Generate password reset token
            $token = $this->jwtService->generatePasswordResetToken($email);
            
            error_log("ForgotPassword: Token generated, storing in database");
            
            // Store password reset token
            $this->storePasswordResetToken($email, $token);

            error_log("ForgotPassword: Token stored, sending email");

            // Send password reset email
            $emailSent = $this->emailService->sendPasswordResetEmail($user, $token);
            
            if (!$emailSent) {
                error_log("Failed to send password reset email to {$email}");
                // Still return true to not reveal if email exists
            } else {
                error_log("Password reset email sent successfully to {$email}");
            }

            return true;
        } catch (\Exception $e) {
            error_log("ForgotPassword Exception: " . $e->getMessage());
            throw $e;
        }
    }

    public function resetPassword(string $token, string $newPassword): bool
    {
        try {
            $email = $this->jwtService->validatePasswordResetToken($token);
            
            if (!$email || !$this->validatePasswordResetToken($email, $token)) {
                throw new \RuntimeException('Invalid or expired reset token', 400);
            }

            $user = $this->userModel->findByEmail($email);
            
            if (!$user) {
                throw new \RuntimeException('User not found', 404);
            }

            // Validate password
            if (strlen($newPassword) < 6) {
                throw new \RuntimeException('Password must be at least 6 characters', 400);
            }

            // Hash new password
            $passwordHash = password_hash($newPassword, PASSWORD_ARGON2ID);
            
            // Update password
            $success = $this->userModel->updatePassword($user['id'], $passwordHash);
            
            if ($success) {
                // Mark reset token as used
                $this->markPasswordResetTokenAsUsed($email, $token);
                // Revoke all user tokens
                $this->revokeAllUserTokens($user['id']);
            }

            return $success;
        } catch (\Exception $e) {
            throw $e;
        }
    }

    public function logout(string $refreshToken): bool
    {
        try {
            $tokenData = $this->jwtService->refreshAccessToken($refreshToken);
            return $this->revokeRefreshToken($tokenData['user_id'], $refreshToken);
        } catch (\Exception $e) {
            return false;
        }
    }

    private function validateRegistrationData(array $data): void
    {
        if (empty($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            throw new \RuntimeException('Valid email is required', 400);
        }

        if (empty($data['password']) || strlen($data['password']) < 6) {
            throw new \RuntimeException('Password must be at least 6 characters', 400);
        }

        if (!empty($data['phone'])) {
            // Basic phone validation (you might want to use a proper phone validation library)
            if (!preg_match('/^\+?[1-9]\d{1,14}$/', $data['phone'])) {
                throw new \RuntimeException('Invalid phone number format', 400);
            }
        }
    }

    private function generateVerificationCode(int $userId, string $type): string
    {
        $code = sprintf('%06d', random_int(100000, 999999));
        $expiresAt = date('Y-m-d H:i:s', strtotime('+10 minutes'));

        $sql = "INSERT INTO verification_codes (user_id, code, type, expires_at) VALUES (?, ?, ?, ?)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $code, $type, $expiresAt]);

        // In production, send SMS here
        error_log("Verification code for user {$userId}: {$code}");

        return $code;
    }

    private function validateVerificationCode(int $userId, string $code, string $type): bool
    {
        $sql = "SELECT id FROM verification_codes 
                WHERE user_id = ? AND code = ? AND type = ? 
                AND expires_at > NOW() AND is_used = 0 AND attempts < 3";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $code, $type]);
        
        if ($stmt->fetch()) {
            // Mark as used
            $updateSql = "UPDATE verification_codes SET is_used = 1 WHERE user_id = ? AND code = ? AND type = ?";
            $updateStmt = $this->db->prepare($updateSql);
            $updateStmt->execute([$userId, $code, $type]);
            
            return true;
        } else {
            // Increment attempts
            $attemptSql = "UPDATE verification_codes SET attempts = attempts + 1 
                          WHERE user_id = ? AND code = ? AND type = ? AND is_used = 0";
            $attemptStmt = $this->db->prepare($attemptSql);
            $attemptStmt->execute([$userId, $code, $type]);
        }

        return false;
    }

    private function storeRefreshToken(int $userId, string $token): void
    {
        $expiresAt = date('Y-m-d H:i:s', strtotime('+7 days'));
        
        $sql = "INSERT INTO user_tokens (user_id, token, type, expires_at) VALUES (?, ?, 'refresh', ?)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $token, $expiresAt]);
    }

    private function validateRefreshToken(int $userId, string $token): bool
    {
        $sql = "SELECT id FROM user_tokens 
                WHERE user_id = ? AND token = ? AND type = 'refresh' 
                AND expires_at > NOW() AND is_revoked = 0";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $token]);
        
        return $stmt->fetch() !== false;
    }

    private function revokeRefreshToken(int $userId, string $token): bool
    {
        $sql = "UPDATE user_tokens SET is_revoked = 1 WHERE user_id = ? AND token = ? AND type = 'refresh'";
        $stmt = $this->db->prepare($sql);
        return $stmt->execute([$userId, $token]);
    }

    private function revokeAllUserTokens(int $userId): bool
    {
        $sql = "UPDATE user_tokens SET is_revoked = 1 WHERE user_id = ?";
        $stmt = $this->db->prepare($sql);
        return $stmt->execute([$userId]);
    }

    private function storePasswordResetToken(string $email, string $token): void
    {
        $expiresAt = date('Y-m-d H:i:s', strtotime('+1 hour'));
        
        $sql = "INSERT INTO password_resets (email, token, expires_at) VALUES (?, ?, ?)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$email, $token, $expiresAt]);
    }

    private function validatePasswordResetToken(string $email, string $token): bool
    {
        $sql = "SELECT id FROM password_resets 
                WHERE email = ? AND token = ? AND expires_at > NOW() AND is_used = 0";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$email, $token]);
        
        return $stmt->fetch() !== false;
    }

    private function markPasswordResetTokenAsUsed(string $email, string $token): bool
    {
        $sql = "UPDATE password_resets SET is_used = 1 WHERE email = ? AND token = ?";
        $stmt = $this->db->prepare($sql);
        return $stmt->execute([$email, $token]);
    }

    private function trackLoginAttempt(string $email, bool $success): void
    {
        $ipAddress = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
        
        $sql = "INSERT INTO login_attempts (email, ip_address, user_agent, success) VALUES (?, ?, ?, ?)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$email, $ipAddress, $userAgent, $success ? 1 : 0]);
    }

    private function sendEmailVerification(array $user): void
    {
        try {
            // Generate unique verification token
            $token = bin2hex(random_bytes(32));
            
            // Store verification token in database
            $this->emailVerificationModel->create($user['id'], $token);
            
            // Send email with verification link
            $firstName = $user['first_name'] ?? 'Utilisateur';
            MailSender::sendEmailVerification($user['email'], $firstName, $token);
            
        } catch (\Exception $e) {
            // Log error but don't fail registration
            error_log('Failed to send email verification: ' . $e->getMessage());
        }
    }

    public function verifyEmail(string $token): bool
    {
        try {
            // Find verification record
            $verification = $this->emailVerificationModel->findByToken($token);
            
            if (!$verification) {
                throw new \RuntimeException('Invalid or expired verification token', 400);
            }
            
            // Mark token as used
            $this->emailVerificationModel->markAsUsed($token);
            
            // Update user as verified
            $success = $this->userModel->verifyEmail($verification['user_id']);
            
            if ($success) {
                // Clean up used tokens for this user
                $this->emailVerificationModel->deleteByUserId($verification['user_id']);
            }
            
            return $success;
            
        } catch (\Exception $e) {
            throw $e;
        }
    }

    public function resendEmailVerification(string $email): bool
    {
        try {
            $user = $this->userModel->findByEmail($email);
            
            if (!$user) {
                throw new \RuntimeException('User not found', 404);
            }
            
            if ($user['is_verified']) {
                throw new \RuntimeException('Email already verified', 400);
            }
            
            // Send new verification email
            $this->sendEmailVerification($user);
            
            return true;
            
        } catch (\Exception $e) {
            throw $e;
        }
    }
}