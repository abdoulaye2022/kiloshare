<?php

declare(strict_types=1);

namespace KiloShare\Models;

use PDO;
use PDOException;
use DateTime;

class User
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function create(array $userData): ?array
    {
        try {
            $sql = "INSERT INTO users (uuid, email, phone, password_hash, first_name, last_name, 
                                     social_provider, social_id, profile_picture, is_verified, email_verified_at) 
                    VALUES (:uuid, :email, :phone, :password_hash, :first_name, :last_name,
                            :social_provider, :social_id, :profile_picture, :is_verified, :email_verified_at)";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([
                ':uuid' => $userData['uuid'],
                ':email' => $userData['email'],
                ':phone' => $userData['phone'] ?? null,
                ':password_hash' => $userData['password_hash'] ?? null,
                ':first_name' => $userData['first_name'] ?? null,
                ':last_name' => $userData['last_name'] ?? null,
                ':social_provider' => $userData['social_provider'] ?? null,
                ':social_id' => $userData['social_id'] ?? null,
                ':profile_picture' => $userData['profile_picture'] ?? null,
                ':is_verified' => $userData['is_verified'] ?? 0,
                ':email_verified_at' => $userData['email_verified_at'] ?? null
            ]);

            $userId = $this->db->lastInsertId();
            return $this->findById((int)$userId);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to create user: ' . $e->getMessage());
        }
    }

    public function findById(int $id): ?array
    {
        try {
            $sql = "SELECT id, uuid, email, phone, first_name, last_name, gender, date_of_birth,
                           nationality, bio, website, profession, company, address_line1, address_line2,
                           city, state_province, postal_code, country, preferred_language, timezone,
                           emergency_contact_name, emergency_contact_phone, emergency_contact_relation,
                           login_method, two_factor_enabled, newsletter_subscribed, marketing_emails,
                           profile_visibility, is_verified, email_verified_at, phone_verified_at,
                           profile_picture, status, role, last_login_at, social_provider, social_id,
                           created_at, updated_at 
                    FROM users WHERE id = :id AND status != 'deleted'";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([':id' => $id]);
            
            $user = $stmt->fetch();
            return $user ?: null;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to find user: ' . $e->getMessage());
        }
    }

    public function findByEmail(string $email): ?array
    {
        try {
            $sql = "SELECT id, uuid, email, phone, password_hash, first_name, last_name, 
                           is_verified, email_verified_at, phone_verified_at, profile_picture, 
                           status, role, last_login_at, social_provider, social_id, created_at, updated_at 
                    FROM users WHERE email = :email AND status != 'deleted'";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([':email' => $email]);
            
            $user = $stmt->fetch();
            return $user ?: null;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to find user by email: ' . $e->getMessage());
        }
    }

    public function findByPhone(string $phone): ?array
    {
        try {
            $sql = "SELECT id, uuid, email, phone, password_hash, first_name, last_name, 
                           is_verified, email_verified_at, phone_verified_at, profile_picture, 
                           status, last_login_at, created_at, updated_at 
                    FROM users WHERE phone = :phone AND status != 'deleted'";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([':phone' => $phone]);
            
            $user = $stmt->fetch();
            return $user ?: null;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to find user by phone: ' . $e->getMessage());
        }
    }

    public function findByUuid(string $uuid): ?array
    {
        try {
            $sql = "SELECT id, uuid, email, phone, first_name, last_name, is_verified, 
                           email_verified_at, phone_verified_at, profile_picture, status, 
                           last_login_at, created_at, updated_at 
                    FROM users WHERE uuid = :uuid AND status != 'deleted'";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([':uuid' => $uuid]);
            
            $user = $stmt->fetch();
            return $user ?: null;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to find user by UUID: ' . $e->getMessage());
        }
    }

    public function updateLastLogin(int $userId): bool
    {
        try {
            $sql = "UPDATE users SET last_login_at = NOW() WHERE id = :id";
            
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([':id' => $userId]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to update last login: ' . $e->getMessage());
        }
    }

    public function verifyEmail(int $userId): bool
    {
        try {
            $sql = "UPDATE users SET is_verified = 1, email_verified_at = NOW() WHERE id = :id";
            
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([':id' => $userId]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to verify email: ' . $e->getMessage());
        }
    }

    public function verifyPhone(int $userId): bool
    {
        try {
            $sql = "UPDATE users SET phone_verified_at = NOW() WHERE id = :id";
            
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([':id' => $userId]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to verify phone: ' . $e->getMessage());
        }
    }

    public function updatePassword(int $userId, string $passwordHash): bool
    {
        try {
            $sql = "UPDATE users SET password_hash = :password_hash, updated_at = NOW() WHERE id = :id";
            
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([
                ':id' => $userId,
                ':password_hash' => $passwordHash
            ]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to update password: ' . $e->getMessage());
        }
    }

    public function updateProfile(int $userId, array $data): bool
    {
        try {
            $fields = [];
            $params = [':id' => $userId];

            // Champs de base
            $allowedFields = [
                'first_name', 'last_name', 'phone', 'profile_picture', 'email',
                'gender', 'date_of_birth', 'nationality', 'bio', 'website',
                'profession', 'company', 'address_line1', 'address_line2',
                'city', 'state_province', 'postal_code', 'country',
                'preferred_language', 'timezone', 'emergency_contact_name',
                'emergency_contact_phone', 'emergency_contact_relation',
                'newsletter_subscribed', 'marketing_emails', 'profile_visibility'
            ];

            foreach ($allowedFields as $field) {
                if (isset($data[$field])) {
                    $fields[] = "$field = :$field";
                    $params[":$field"] = $data[$field];
                }
            }

            if (empty($fields)) {
                return false;
            }

            $fields[] = 'updated_at = NOW()';
            $sql = "UPDATE users SET " . implode(', ', $fields) . " WHERE id = :id";
            
            $stmt = $this->db->prepare($sql);
            return $stmt->execute($params);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to update profile: ' . $e->getMessage());
        }
    }

    public function emailExists(string $email): bool
    {
        try {
            $sql = "SELECT COUNT(*) FROM users WHERE email = :email AND status != 'deleted'";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([':email' => $email]);
            
            return $stmt->fetchColumn() > 0;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to check email existence: ' . $e->getMessage());
        }
    }

    public function phoneExists(string $phone): bool
    {
        try {
            $sql = "SELECT COUNT(*) FROM users WHERE phone = :phone AND status != 'deleted'";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([':phone' => $phone]);
            
            return $stmt->fetchColumn() > 0;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to check phone existence: ' . $e->getMessage());
        }
    }

    /**
     * Get database connection
     */
    public function getDb(): PDO
    {
        return $this->db;
    }

    /**
     * Valide les données de profil selon la méthode de connexion
     */
    public function validateProfileUpdate(int $userId, array $data): array
    {
        $user = $this->findById($userId);
        if (!$user) {
            return ['valid' => false, 'message' => 'Utilisateur non trouvé'];
        }

        $loginMethod = $user['login_method'] ?? 'email';
        
        // Validation spéciale pour les utilisateurs connectés par téléphone
        if ($loginMethod === 'phone') {
            // Le numéro de téléphone est obligatoire pour ces utilisateurs
            if (isset($data['phone']) && (empty($data['phone']) || $data['phone'] === '')) {
                return ['valid' => false, 'message' => 'Le numéro de téléphone est obligatoire car vous vous connectez avec votre téléphone'];
            }
            
            // Vérifier que le nouveau numéro n'est pas déjà utilisé par un autre utilisateur
            if (isset($data['phone']) && $data['phone'] !== $user['phone']) {
                if ($this->phoneExists($data['phone'])) {
                    return ['valid' => false, 'message' => 'Ce numéro de téléphone est déjà utilisé par un autre compte'];
                }
            }
        }
        
        // Validation spéciale pour les utilisateurs connectés par email
        if ($loginMethod === 'email') {
            // L'email est obligatoire pour ces utilisateurs
            if (isset($data['email']) && (empty($data['email']) || $data['email'] === '')) {
                return ['valid' => false, 'message' => 'L\'adresse email est obligatoire car vous vous connectez avec votre email'];
            }
            
            // Vérifier que le nouvel email n'est pas déjà utilisé par un autre utilisateur
            if (isset($data['email']) && $data['email'] !== $user['email']) {
                if ($this->emailExists($data['email'])) {
                    return ['valid' => false, 'message' => 'Cette adresse email est déjà utilisée par un autre compte'];
                }
            }
        }

        // Validations générales
        if (isset($data['email']) && !empty($data['email']) && !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            return ['valid' => false, 'message' => 'Format d\'email invalide'];
        }

        if (isset($data['phone']) && !empty($data['phone']) && !preg_match('/^\+?[\d\s\-\(\)\.]{8,}$/', $data['phone'])) {
            return ['valid' => false, 'message' => 'Format de numéro de téléphone invalide'];
        }

        if (isset($data['date_of_birth']) && !empty($data['date_of_birth'])) {
            $birthDate = \DateTime::createFromFormat('Y-m-d', $data['date_of_birth']);
            if (!$birthDate) {
                return ['valid' => false, 'message' => 'Format de date de naissance invalide (YYYY-MM-DD)'];
            }
            
            $age = $birthDate->diff(new \DateTime())->y;
            if ($age < 13) {
                return ['valid' => false, 'message' => 'L\'âge minimum requis est de 13 ans'];
            }
            if ($age > 120) {
                return ['valid' => false, 'message' => 'Veuillez vérifier votre date de naissance'];
            }
        }

        if (isset($data['website']) && !empty($data['website']) && !filter_var($data['website'], FILTER_VALIDATE_URL)) {
            return ['valid' => false, 'message' => 'URL du site web invalide'];
        }

        return ['valid' => true];
    }

    /**
     * Normalize user data for API responses
     */
    public static function normalizeForApi(array $user): array
    {
        if (isset($user['is_verified'])) {
            $user['is_verified'] = (bool)$user['is_verified'];
        }
        
        if (isset($user['two_factor_enabled'])) {
            $user['two_factor_enabled'] = (bool)$user['two_factor_enabled'];
        }
        
        if (isset($user['newsletter_subscribed'])) {
            $user['newsletter_subscribed'] = (bool)$user['newsletter_subscribed'];
        }
        
        if (isset($user['marketing_emails'])) {
            $user['marketing_emails'] = (bool)$user['marketing_emails'];
        }
        
        return $user;
    }
}