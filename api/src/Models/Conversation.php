<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Exception;

class Conversation extends Model
{
    protected $table = 'conversations';

    public const TYPE_NEGOTIATION = 'negotiation';
    public const TYPE_POST_PAYMENT = 'post_payment';
    public const TYPE_SUPPORT = 'support';

    public const STATUS_ACTIVE = 'active';
    public const STATUS_ARCHIVED = 'archived';
    public const STATUS_BLOCKED = 'blocked';

    public function createConversation(int $bookingId, string $type = self::TYPE_NEGOTIATION): int
    {
        $data = [
            'booking_id' => $bookingId,
            'type' => $type,
            'status' => self::STATUS_ACTIVE,
            'created_at' => date('Y-m-d H:i:s'),
        ];

        return $this->create($data);
    }

    public function findByBooking(int $bookingId, string $type = null): ?array
    {
        $sql = "SELECT * FROM {$this->table} WHERE booking_id = ?";
        $params = [$bookingId];

        if ($type) {
            $sql .= " AND type = ?";
            $params[] = $type;
        }

        $sql .= " ORDER BY created_at DESC LIMIT 1";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        
        $result = $stmt->fetch(\PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function getUserConversations(int $userId, int $limit = 20, int $offset = 0): array
    {
        $sql = "
            SELECT c.*, 
                   b.trip_id, b.status as booking_status,
                   t.title as trip_title, t.departure_date,
                   u1.first_name as driver_name, u2.first_name as passenger_name,
                   (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE) as message_count,
                   (SELECT COUNT(*) FROM messages m 
                    LEFT JOIN message_reads mr ON m.id = mr.message_id AND mr.user_id = ?
                    WHERE m.conversation_id = c.id AND mr.id IS NULL AND m.sender_id != ? AND m.is_deleted = FALSE) as unread_count,
                   (SELECT m.content FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1) as last_message,
                   (SELECT m.message_type FROM messages m WHERE m.conversation_id = c.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1) as last_message_type
            FROM conversations c
            INNER JOIN conversation_participants cp ON c.id = cp.conversation_id
            INNER JOIN bookings b ON c.booking_id = b.id
            INNER JOIN trips t ON b.trip_id = t.id
            LEFT JOIN users u1 ON b.driver_id = u1.id
            LEFT JOIN users u2 ON b.user_id = u2.id
            WHERE cp.user_id = ? AND cp.is_active = TRUE AND c.status = 'active'
            ORDER BY c.last_message_at DESC, c.updated_at DESC
            LIMIT ? OFFSET ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $userId, $userId, $limit, $offset]);
        
        return $stmt->fetchAll(\PDO::FETCH_ASSOC);
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

    public function removeParticipant(int $conversationId, int $userId): bool
    {
        $sql = "
            UPDATE conversation_participants 
            SET is_active = FALSE, left_at = NOW() 
            WHERE conversation_id = ? AND user_id = ?
        ";

        $stmt = $this->db->prepare($sql);
        return $stmt->execute([$conversationId, $userId]);
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
        
        return $stmt->fetchAll(\PDO::FETCH_ASSOC);
    }

    public function archiveConversation(int $conversationId): bool
    {
        $sql = "
            UPDATE {$this->table} 
            SET status = 'archived', archived_at = NOW() 
            WHERE id = ?
        ";

        $stmt = $this->db->prepare($sql);
        return $stmt->execute([$conversationId]);
    }

    public function autoArchiveOldConversations(int $daysOld = 30): int
    {
        $sql = "
            UPDATE {$this->table} c
            INNER JOIN bookings b ON c.booking_id = b.id
            SET c.status = 'archived', c.archived_at = NOW()
            WHERE c.status = 'active' 
            AND b.status IN ('completed', 'cancelled', 'expired')
            AND c.last_message_at < DATE_SUB(NOW(), INTERVAL ? DAY)
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$daysOld]);
        
        return $stmt->rowCount();
    }

    public function upgradeToPostPayment(int $bookingId): ?int
    {
        // Check if post-payment conversation already exists
        $existing = $this->findByBooking($bookingId, self::TYPE_POST_PAYMENT);
        if ($existing) {
            return $existing['id'];
        }

        // Create new post-payment conversation
        $conversationId = $this->createConversation($bookingId, self::TYPE_POST_PAYMENT);

        // Copy participants from negotiation conversation
        $negotiationConv = $this->findByBooking($bookingId, self::TYPE_NEGOTIATION);
        if ($negotiationConv) {
            $participants = $this->getParticipants($negotiationConv['id']);
            foreach ($participants as $participant) {
                $this->addParticipant($conversationId, $participant['user_id'], $participant['role']);
            }
        }

        return $conversationId;
    }

    public function getConversationContext(int $conversationId): ?array
    {
        $sql = "
            SELECT c.*, b.status as booking_status, b.payment_status, b.pickup_code, b.delivery_code,
                   t.title as trip_title, t.departure_date, t.departure_location, t.arrival_location,
                   u1.first_name as driver_first_name, u1.last_name as driver_last_name,
                   u2.first_name as passenger_first_name, u2.last_name as passenger_last_name,
                   p.status as payment_confirmed
            FROM conversations c
            INNER JOIN bookings b ON c.booking_id = b.id
            INNER JOIN trips t ON b.trip_id = t.id
            LEFT JOIN users u1 ON b.driver_id = u1.id
            LEFT JOIN users u2 ON b.user_id = u2.id
            LEFT JOIN payments p ON b.id = p.booking_id AND p.status = 'completed'
            WHERE c.id = ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId]);
        
        $result = $stmt->fetch(\PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function getUnreadCount(int $userId): int
    {
        $sql = "
            SELECT COUNT(DISTINCT c.id)
            FROM conversations c
            INNER JOIN conversation_participants cp ON c.id = cp.conversation_id
            INNER JOIN messages m ON c.id = m.conversation_id
            LEFT JOIN message_reads mr ON m.id = mr.message_id AND mr.user_id = ?
            WHERE cp.user_id = ? AND cp.is_active = TRUE 
            AND c.status = 'active' AND m.sender_id != ?
            AND mr.id IS NULL AND m.is_deleted = FALSE
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $userId, $userId]);
        
        return (int)$stmt->fetchColumn();
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
            $existing = $stmt->fetch(\PDO::FETCH_ASSOC);

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
            $result = $stmt->fetch(\PDO::FETCH_ASSOC);

            return $result ?: null;

        } catch (Exception $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            error_log("Failed to create trip conversation: " . $e->getMessage());
            return null;
        }
    }
}