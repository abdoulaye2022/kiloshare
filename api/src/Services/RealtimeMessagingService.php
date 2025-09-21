<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Exception;

class RealtimeMessagingService
{
    private string $firebaseProjectId;
    private string $firebasePrivateKey;
    private array $connectedUsers = [];

    public function __construct()
    {
        $this->firebaseProjectId = $_ENV['FIREBASE_PROJECT_ID'] ?? '';
        $this->firebasePrivateKey = $_ENV['FIREBASE_PRIVATE_KEY_PATH'] ?? '';
    }

    /**
     * Notify users in a conversation about new message via Firebase
     */
    public function notifyNewMessage(array $message, array $participants): bool
    {
        try {
            $payload = [
                'type' => 'new_message',
                'data' => [
                    'conversation_id' => $message['conversation_id'],
                    'message_id' => $message['id'],
                    'sender_id' => $message['sender_id'],
                    'content' => $message['content'],
                    'message_type' => $message['message_type'],
                    'created_at' => $message['created_at'],
                    'contacts_revealed' => $message['contacts_revealed'] ?? false
                ]
            ];

            foreach ($participants as $participant) {
                // Don't notify the sender
                if ($participant['user_id'] != $message['sender_id']) {
                    $this->sendRealtimeUpdate($participant['user_id'], $payload);
                }
            }

            return true;

        } catch (Exception $e) {
            error_log("Failed to notify new message: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notify about typing indicators
     */
    public function notifyTyping(int $conversationId, int $userId, bool $isTyping): bool
    {
        try {
            $payload = [
                'type' => 'typing_indicator',
                'data' => [
                    'conversation_id' => $conversationId,
                    'user_id' => $userId,
                    'is_typing' => $isTyping,
                    'timestamp' => date('c')
                ]
            ];

            // Get conversation participants
            $conversation = new \KiloShare\Models\Conversation();
            $participants = $conversation->getParticipants($conversationId);

            foreach ($participants as $participant) {
                // Don't notify the typing user
                if ($participant['user_id'] != $userId) {
                    $this->sendRealtimeUpdate($participant['user_id'], $payload);
                }
            }

            return true;

        } catch (Exception $e) {
            error_log("Failed to notify typing: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notify about message read status
     */
    public function notifyMessageRead(int $conversationId, int $messageId, int $readerId): bool
    {
        try {
            $payload = [
                'type' => 'message_read',
                'data' => [
                    'conversation_id' => $conversationId,
                    'message_id' => $messageId,
                    'reader_id' => $readerId,
                    'read_at' => date('c')
                ]
            ];

            // Get conversation participants
            $conversation = new \KiloShare\Models\Conversation();
            $participants = $conversation->getParticipants($conversationId);

            foreach ($participants as $participant) {
                // Don't notify the reader
                if ($participant['user_id'] != $readerId) {
                    $this->sendRealtimeUpdate($participant['user_id'], $payload);
                }
            }

            return true;

        } catch (Exception $e) {
            error_log("Failed to notify message read: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notify about contact revelation after payment
     */
    public function notifyContactsRevealed(int $conversationId, int $bookingId): bool
    {
        try {
            $payload = [
                'type' => 'contacts_revealed',
                'data' => [
                    'conversation_id' => $conversationId,
                    'booking_id' => $bookingId,
                    'revealed_at' => date('c')
                ]
            ];

            // Get conversation participants
            $conversation = new \KiloShare\Models\Conversation();
            $participants = $conversation->getParticipants($conversationId);

            foreach ($participants as $participant) {
                $this->sendRealtimeUpdate($participant['user_id'], $payload);
            }

            return true;

        } catch (Exception $e) {
            error_log("Failed to notify contacts revealed: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Notify about conversation status changes
     */
    public function notifyConversationStatus(int $conversationId, string $status, array $data = []): bool
    {
        try {
            $payload = [
                'type' => 'conversation_status_changed',
                'data' => array_merge([
                    'conversation_id' => $conversationId,
                    'status' => $status,
                    'changed_at' => date('c')
                ], $data)
            ];

            // Get conversation participants
            $conversation = new \KiloShare\Models\Conversation();
            $participants = $conversation->getParticipants($conversationId);

            foreach ($participants as $participant) {
                $this->sendRealtimeUpdate($participant['user_id'], $payload);
            }

            return true;

        } catch (Exception $e) {
            error_log("Failed to notify conversation status: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Send presence updates (online/offline)
     */
    public function updateUserPresence(int $userId, bool $isOnline): bool
    {
        try {
            // Update user's online status
            $this->updateUserOnlineStatus($userId, $isOnline);

            $payload = [
                'type' => 'user_presence',
                'data' => [
                    'user_id' => $userId,
                    'is_online' => $isOnline,
                    'last_seen' => date('c')
                ]
            ];

            // Get user's active conversations to notify other participants
            $conversation = new \KiloShare\Models\Conversation();
            $userConversations = $conversation->getUserConversations($userId, 50, 0);

            $notifiedUsers = [];
            foreach ($userConversations as $conv) {
                $participants = $conversation->getParticipants($conv['id']);
                
                foreach ($participants as $participant) {
                    if ($participant['user_id'] != $userId && !in_array($participant['user_id'], $notifiedUsers)) {
                        $this->sendRealtimeUpdate($participant['user_id'], $payload);
                        $notifiedUsers[] = $participant['user_id'];
                    }
                }
            }

            return true;

        } catch (Exception $e) {
            error_log("Failed to update user presence: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Send real-time update to specific user via Firebase Realtime Database
     */
    private function sendRealtimeUpdate(int $userId, array $payload): bool
    {
        try {
            if (!$this->firebaseProjectId) {
                // Fallback to in-memory storage for testing
                $this->storeInMemoryUpdate($userId, $payload);
                return true;
            }

            // Firebase Realtime Database REST API
            $url = "https://{$this->firebaseProjectId}-default-rtdb.firebaseio.com/users/{$userId}/realtime_updates.json";
            
            $postData = json_encode([
                'timestamp' => time(),
                'payload' => $payload
            ]);

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Content-Length: ' . strlen($postData)
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            return $httpCode >= 200 && $httpCode < 300;

        } catch (Exception $e) {
            error_log("Failed to send realtime update: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Store update in memory for testing/fallback
     */
    private function storeInMemoryUpdate(int $userId, array $payload): void
    {
        if (!isset($this->connectedUsers[$userId])) {
            $this->connectedUsers[$userId] = [];
        }

        $this->connectedUsers[$userId][] = [
            'timestamp' => time(),
            'payload' => $payload
        ];

        // Keep only last 50 updates per user
        if (count($this->connectedUsers[$userId]) > 50) {
            array_shift($this->connectedUsers[$userId]);
        }
    }

    /**
     * Get pending updates for a user (for polling fallback)
     */
    public function getPendingUpdates(int $userId, int $since = 0): array
    {
        if (!isset($this->connectedUsers[$userId])) {
            return [];
        }

        return array_filter($this->connectedUsers[$userId], function($update) use ($since) {
            return $update['timestamp'] > $since;
        });
    }

    /**
     * Update user online status in database
     */
    private function updateUserOnlineStatus(int $userId, bool $isOnline): void
    {
        try {
            global $pdo;
            $sql = "
                INSERT INTO user_presence (user_id, is_online, last_seen) 
                VALUES (?, ?, NOW())
                ON DUPLICATE KEY UPDATE 
                is_online = VALUES(is_online), 
                last_seen = NOW()
            ";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$userId, $isOnline]);

        } catch (Exception $e) {
            error_log("Failed to update user online status: " . $e->getMessage());
        }
    }

    /**
     * Get online users in a conversation
     */
    public function getOnlineUsers(int $conversationId): array
    {
        try {
            global $pdo;
            $sql = "
                SELECT u.id, u.first_name, u.last_name, up.last_seen
                FROM conversation_participants cp
                INNER JOIN users u ON cp.user_id = u.id
                LEFT JOIN user_presence up ON u.id = up.user_id
                WHERE cp.conversation_id = ? AND cp.is_active = TRUE
                AND (up.is_online = TRUE OR up.last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE))
            ";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$conversationId]);
            
            return $stmt->fetchAll(\PDO::FETCH_ASSOC);

        } catch (Exception $e) {
            error_log("Failed to get online users: " . $e->getMessage());
            return [];
        }
    }

    /**
     * Clean up old presence records
     */
    public function cleanupPresence(): int
    {
        try {
            global $pdo;
            $sql = "DELETE FROM user_presence WHERE last_seen < DATE_SUB(NOW(), INTERVAL 1 DAY)";
            $stmt = $pdo->prepare($sql);
            $stmt->execute();
            
            return $stmt->rowCount();

        } catch (Exception $e) {
            error_log("Failed to cleanup presence: " . $e->getMessage());
            return 0;
        }
    }
}