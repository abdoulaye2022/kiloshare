<?php

declare(strict_types=1);

namespace KiloShare\Modules\Auth\Models;

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
            $sql = "INSERT INTO users (uuid, email, phone, password_hash, first_name, last_name) 
                    VALUES (:uuid, :email, :phone, :password_hash, :first_name, :last_name)";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([
                ':uuid' => $userData['uuid'],
                ':email' => $userData['email'],
                ':phone' => $userData['phone'] ?? null,
                ':password_hash' => $userData['password_hash'],
                ':first_name' => $userData['first_name'] ?? null,
                ':last_name' => $userData['last_name'] ?? null
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
            $sql = "SELECT id, uuid, email, phone, first_name, last_name, is_verified, 
                           email_verified_at, phone_verified_at, profile_picture, status, 
                           last_login_at, created_at, updated_at 
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
                           status, last_login_at, created_at, updated_at 
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

            if (isset($data['first_name'])) {
                $fields[] = 'first_name = :first_name';
                $params[':first_name'] = $data['first_name'];
            }

            if (isset($data['last_name'])) {
                $fields[] = 'last_name = :last_name';
                $params[':last_name'] = $data['last_name'];
            }

            if (isset($data['phone'])) {
                $fields[] = 'phone = :phone';
                $params[':phone'] = $data['phone'];
            }

            if (isset($data['profile_picture'])) {
                $fields[] = 'profile_picture = :profile_picture';
                $params[':profile_picture'] = $data['profile_picture'];
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
}