<?php

declare(strict_types=1);

namespace KiloShare\Models;

use PDO;
use PDOException;

class EmailVerification
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function create(int $userId, string $token): bool
    {
        try {
            // Supprimer les anciens tokens de vérification pour cet utilisateur
            $this->deleteByUserId($userId);

            $sql = "INSERT INTO email_verifications (user_id, token, expires_at) VALUES (?, ?, ?)";
            $stmt = $this->db->prepare($sql);
            
            // Token expire dans 24 heures
            $expiresAt = date('Y-m-d H:i:s', strtotime('+24 hours'));
            
            return $stmt->execute([$userId, $token, $expiresAt]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to create email verification: ' . $e->getMessage());
        }
    }

    public function findByToken(string $token): ?array
    {
        try {
            $sql = "SELECT ev.*, u.email, u.first_name, u.last_name 
                    FROM email_verifications ev
                    JOIN users u ON ev.user_id = u.id
                    WHERE ev.token = ? AND ev.expires_at > NOW() AND ev.is_used = 0";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$token]);
            
            $result = $stmt->fetch();
            return $result ?: null;
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to find email verification: ' . $e->getMessage());
        }
    }

    public function markAsUsed(string $token): bool
    {
        try {
            $sql = "UPDATE email_verifications SET is_used = 1, used_at = NOW() WHERE token = ?";
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([$token]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to mark email verification as used: ' . $e->getMessage());
        }
    }

    public function deleteByUserId(int $userId): bool
    {
        try {
            $sql = "DELETE FROM email_verifications WHERE user_id = ?";
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([$userId]);
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to delete email verifications: ' . $e->getMessage());
        }
    }

    public function cleanupExpired(): int
    {
        try {
            $sql = "DELETE FROM email_verifications WHERE expires_at <= NOW()";
            $stmt = $this->db->prepare($sql);
            $stmt->execute();
            return $stmt->rowCount();
        } catch (PDOException $e) {
            throw new \RuntimeException('Failed to cleanup expired verifications: ' . $e->getMessage());
        }
    }
}