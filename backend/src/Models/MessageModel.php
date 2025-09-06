<?php

declare(strict_types=1);

namespace KiloShare\Models;

use PDO;
use Exception;
use KiloShare\Utils\Database;

class MessageModel
{
    private PDO $db;

    public const TYPE_TEXT = 'text';
    public const TYPE_IMAGE = 'image';
    public const TYPE_LOCATION = 'location';
    public const TYPE_SYSTEM = 'system';
    public const TYPE_ACTION = 'action';

    public function __construct()
    {
        $this->db = Database::getConnection()->getPdo();
    }

    public function sendMessage(int $conversationId, int $senderId, string $content, string $messageType = self::TYPE_TEXT, array $metadata = []): array
    {
        try {
            $sql = "
                INSERT INTO messages (conversation_id, sender_id, message_type, content, metadata, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, NOW(), NOW())
            ";

            $stmt = $this->db->prepare($sql);
            $success = $stmt->execute([
                $conversationId,
                $senderId,
                $messageType,
                $content,
                json_encode($metadata)
            ]);

            if ($success) {
                $messageId = (int)$this->db->lastInsertId();
                return [
                    'success' => true,
                    'message_id' => $messageId,
                    'message' => 'Message sent successfully'
                ];
            } else {
                return [
                    'success' => false,
                    'error' => 'Failed to insert message'
                ];
            }

        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => 'Database error: ' . $e->getMessage()
            ];
        }
    }

    public function getConversationMessages(int $conversationId, int $userId, int $limit = 50, int $offset = 0): array
    {
        $sql = "
            SELECT m.*, u.first_name, u.last_name, u.profile_picture
            FROM messages m
            INNER JOIN users u ON m.sender_id = u.id
            WHERE m.conversation_id = ? AND m.is_deleted = FALSE
            ORDER BY m.created_at ASC
            LIMIT ? OFFSET ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId, $limit, $offset]);
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function markConversationAsRead(int $conversationId, int $userId): bool
    {
        try {
            // Get all unread messages in this conversation for this user
            $sql = "
                SELECT m.id 
                FROM messages m
                LEFT JOIN message_reads mr ON m.id = mr.message_id AND mr.user_id = ?
                WHERE m.conversation_id = ? AND m.sender_id != ? AND mr.id IS NULL AND m.is_deleted = FALSE
            ";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId, $conversationId, $userId]);
            $unreadMessages = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // Mark all as read
            foreach ($unreadMessages as $message) {
                $insertSql = "
                    INSERT IGNORE INTO message_reads (message_id, user_id, read_at) 
                    VALUES (?, ?, NOW())
                ";
                $insertStmt = $this->db->prepare($insertSql);
                $insertStmt->execute([$message['id'], $userId]);
            }

            return true;

        } catch (Exception $e) {
            return false;
        }
    }
}