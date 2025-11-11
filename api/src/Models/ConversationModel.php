<?php

declare(strict_types=1);

namespace KiloShare\Models;

use PDO;
use Exception;
use KiloShare\Utils\Database;

class ConversationModel
{
    private PDO $db;

    public const TYPE_NEGOTIATION = 'negotiation';
    public const TYPE_POST_PAYMENT = 'post_payment';
    public const TYPE_SUPPORT = 'support';
    public const TYPE_TRIP_INQUIRY = 'trip_inquiry';

    public const STATUS_ACTIVE = 'active';
    public const STATUS_ARCHIVED = 'archived';
    public const STATUS_BLOCKED = 'blocked';

    public function __construct()
    {
        $this->db = Database::getConnection()->getPdo();
    }

    /**
     * Get or create conversation for a specific trip between user and trip owner
     */
    public function getOrCreateForTrip(int $tripId, int $userId, int $tripOwnerId): ?array
    {
        try {
            // First check if a conversation already exists for this trip between these users
            $sql = "
                SELECT c.*, t.departure_city, t.arrival_city, t.departure_date
                FROM conversations c
                INNER JOIN trips t ON c.trip_id = t.id
                INNER JOIN conversation_participants cp1 ON c.id = cp1.conversation_id AND cp1.user_id = ?
                INNER JOIN conversation_participants cp2 ON c.id = cp2.conversation_id AND cp2.user_id = ?
                WHERE c.trip_id = ? AND c.status = 'active' AND cp1.is_active = TRUE AND cp2.is_active = TRUE
                ORDER BY c.created_at DESC
                LIMIT 1
            ";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId, $tripOwnerId, $tripId]);
            $existing = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($existing) {
                return $existing;
            }

            // Create new conversation for trip
            $this->db->beginTransaction();

            $insertSql = "
                INSERT INTO conversations (trip_id, type, status, created_at, updated_at) 
                VALUES (?, 'trip_inquiry', 'active', NOW(), NOW())
            ";

            $stmt = $this->db->prepare($insertSql);
            $stmt->execute([$tripId]);
            $conversationId = (int)$this->db->lastInsertId();

            // Add both participants
            $this->addParticipant($conversationId, $userId, 'inquirer');
            $this->addParticipant($conversationId, $tripOwnerId, 'trip_owner');

            $this->db->commit();

            // Return the created conversation with trip details
            $sql = "
                SELECT c.*, t.departure_city, t.arrival_city, t.departure_date
                FROM conversations c
                INNER JOIN trips t ON c.trip_id = t.id
                WHERE c.id = ?
            ";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$conversationId]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);

            return $result ?: null;

        } catch (Exception $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            error_log("Failed to create trip conversation: " . $e->getMessage());
            return null;
        }
    }

    public function addParticipant(int $conversationId, int $userId, string $role): bool
    {
        $sql = "
            INSERT INTO conversation_participants (conversation_id, user_id, role, joined_at) 
            VALUES (?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE is_active = TRUE, joined_at = NOW()
        ";

        try {
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([$conversationId, $userId, $role]);
        } catch (Exception $e) {
            return false;
        }
    }

    public function isParticipant(int $conversationId, int $userId): bool
    {
        $sql = "
            SELECT COUNT(*) 
            FROM conversation_participants 
            WHERE conversation_id = ? AND user_id = ? AND is_active = TRUE
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId, $userId]);
        
        return (int)$stmt->fetchColumn() > 0;
    }

    public function getConversationMessages(int $conversationId, int $userId, int $limit = 50, int $offset = 0): array
    {
        // Verify user is participant
        if (!$this->isParticipant($conversationId, $userId)) {
            return [];
        }

        $sql = "
            SELECT m.*, u.first_name, u.last_name, u.profile_picture
            FROM messages m
            INNER JOIN users u ON m.sender_id = u.id
            WHERE m.conversation_id = ? AND m.is_deleted = FALSE
            ORDER BY m.created_at DESC
            LIMIT ? OFFSET ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId, $limit, $offset]);
        
        return array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function findByBooking(int $bookingId, ?string $type = null): ?array
    {
        $sql = "SELECT * FROM conversations WHERE booking_id = ?";
        $params = [$bookingId];

        if ($type) {
            $sql .= " AND type = ?";
            $params[] = $type;
        }

        $sql .= " ORDER BY created_at DESC LIMIT 1";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function getConversationContext(int $conversationId): ?array
    {
        $sql = "
            SELECT c.id,
                   c.booking_id,
                   c.trip_id,
                   c.type,
                   c.status,
                   c.created_at,
                   c.updated_at,
                   c.last_message_at,
                   c.archived_at,
                   b.status as booking_status,
                   b.payment_status,
                   b.payment_confirmed_at,
                   COALESCE(t.title, t.departure_city) as trip_title,
                   t.departure_date,
                   t.departure_city as departure_location,
                   t.arrival_city as arrival_location,
                   t.user_id as trip_owner_id,
                   u1.first_name as driver_first_name,
                   u1.last_name as driver_last_name,
                   u2.first_name as passenger_first_name,
                   u2.last_name as passenger_last_name
            FROM conversations c
            LEFT JOIN bookings b ON c.booking_id = b.id
            LEFT JOIN trips t ON (c.trip_id = t.id OR b.trip_id = t.id)
            LEFT JOIN users u1 ON COALESCE(b.receiver_id, t.user_id) = u1.id
            LEFT JOIN users u2 ON b.sender_id = u2.id
            WHERE c.id = ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function getParticipants(int $conversationId): array
    {
        $sql = "
            SELECT cp.*, u.first_name, u.last_name, u.email, u.phone, u.profile_picture
            FROM conversation_participants cp
            INNER JOIN users u ON cp.user_id = u.id
            WHERE cp.conversation_id = ? AND cp.is_active = TRUE
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId]);
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function createConversation(int $bookingId, string $type = self::TYPE_NEGOTIATION): int
    {
        $sql = "
            INSERT INTO conversations (booking_id, type, status, created_at) 
            VALUES (?, ?, 'active', NOW())
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$bookingId, $type]);
        
        return (int)$this->db->lastInsertId();
    }

    public function getUserConversations(int $userId, int $limit = 20, int $offset = 0): array
    {
        $sql = "
            SELECT c.*, 
                   t.departure_city, t.arrival_city, t.departure_date,
                   u1.id as other_user_id, u1.first_name as other_user_first_name, u1.last_name as other_user_last_name,
                   (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE) as message_count,
                   (SELECT m.content FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1) as last_message,
                   (SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1) as last_message_at
            FROM conversations c
            INNER JOIN conversation_participants cp ON c.id = cp.conversation_id
            LEFT JOIN trips t ON c.trip_id = t.id
            LEFT JOIN conversation_participants cp2 ON c.id = cp2.conversation_id AND cp2.user_id != ?
            LEFT JOIN users u1 ON cp2.user_id = u1.id
            WHERE cp.user_id = ? AND cp.is_active = TRUE AND c.status = 'active'
            ORDER BY 
                COALESCE((SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1), c.created_at) DESC
            LIMIT ? OFFSET ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $userId, $limit, $offset]);
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}