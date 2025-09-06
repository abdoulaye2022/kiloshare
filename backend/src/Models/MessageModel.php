<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Exception;
use PDO;

class MessageModel
{
    private PDO $db;
    protected string $table = 'messages';

    public const TYPE_TEXT = 'text';
    public const TYPE_IMAGE = 'image';
    public const TYPE_LOCATION = 'location';
    public const TYPE_SYSTEM = 'system';
    public const TYPE_ACTION = 'action';

    public const MODERATION_PENDING = 'pending';
    public const MODERATION_APPROVED = 'approved';
    public const MODERATION_FLAGGED = 'flagged';
    public const MODERATION_BLOCKED = 'blocked';

    private array $contactPatterns = [
        'phone' => '/(?:\+33|0)[1-9](?:[0-9]{8})|(?:\+\d{1,3}[\s\-]?)?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{4}/',
        'email' => '/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/',
        'whatsapp' => '/whatsapp|what\'s app|wa\.me|whats app/i',
        'instagram' => '/@[a-zA-Z0-9_.]+|instagram\.com|insta:/i',
        'facebook' => '/facebook\.com|fb\.com|messenger\.com/i',
        'telegram' => '/@[a-zA-Z0-9_]+|t\.me|telegram/i',
        'url' => '/https?:\/\/[^\s]+/'
    ];

    private array $suspiciousKeywords = [
        'paiement', 'virement', 'paypal', 'iban', 'rib', 'bitcoin', 'crypto',
        'western union', 'moneygram', 'mandatcash', 'money', 'argent',
        'contournement', 'éviter', 'direct', 'sans passer par',
        'hors plateforme', 'externe', 'autre application'
    ];

    public function __construct()
    {
        global $pdo;
        $this->db = $pdo;
    }

    public function create(array $data): int
    {
        $columns = implode(', ', array_keys($data));
        $placeholders = ':' . implode(', :', array_keys($data));
        
        $sql = "INSERT INTO {$this->table} ({$columns}) VALUES ({$placeholders})";
        $stmt = $this->db->prepare($sql);
        
        $stmt->execute($data);
        return (int)$this->db->lastInsertId();
    }

    public function sendMessage(
        int $conversationId, 
        int $senderId, 
        string $content, 
        string $type = self::TYPE_TEXT,
        array $metadata = []
    ): ?int {
        // Check rate limiting
        if (!$this->checkRateLimit($conversationId, $senderId)) {
            throw new Exception('Rate limit exceeded');
        }

        // Moderate content
        $moderationResult = $this->moderateContent($content, $type);
        
        $data = [
            'conversation_id' => $conversationId,
            'sender_id' => $senderId,
            'message_type' => $type,
            'content' => $moderationResult['masked_content'] ?? $content,
            'metadata' => !empty($metadata) ? json_encode($metadata) : null,
            'is_masked' => $moderationResult['is_masked'] ?? false,
            'masking_reason' => $moderationResult['masking_reason'] ?? null,
            'original_content' => $moderationResult['is_masked'] ? $content : null,
            'moderation_status' => $moderationResult['status'],
            'moderation_flags' => !empty($moderationResult['flags']) ? json_encode($moderationResult['flags']) : null,
            'created_at' => date('Y-m-d H:i:s')
        ];

        $messageId = $this->create($data);

        if ($messageId && !empty($moderationResult['flags'])) {
            $this->logModerationAction($messageId, 'flagged', 'Auto-moderation', $moderationResult['flags']);
        }

        // Update rate limiting
        $this->updateRateLimit($conversationId, $senderId);

        return $messageId;
    }

    public function sendSystemMessage(
        int $conversationId,
        string $systemAction,
        array $systemData = [],
        string $content = ''
    ): ?int {
        $data = [
            'conversation_id' => $conversationId,
            'sender_id' => 0, // System messages
            'message_type' => self::TYPE_SYSTEM,
            'content' => $content,
            'system_action' => $systemAction,
            'system_data' => !empty($systemData) ? json_encode($systemData) : null,
            'moderation_status' => self::MODERATION_APPROVED,
            'created_at' => date('Y-m-d H:i:s')
        ];

        return $this->create($data);
    }

    public function getConversationMessages(
        int $conversationId, 
        int $userId,
        int $limit = 50, 
        int $offset = 0
    ): array {
        // Check if user is participant
        $conversation = new Conversation();
        if (!$conversation->isParticipant($conversationId, $userId)) {
            return [];
        }

        $sql = "
            SELECT m.*, u.first_name, u.last_name, u.profile_picture,
                   (SELECT COUNT(*) FROM message_reads mr WHERE mr.message_id = m.id) as read_count,
                   (SELECT COUNT(*) FROM message_attachments ma WHERE ma.message_id = m.id) as attachment_count
            FROM {$this->table} m
            LEFT JOIN users u ON m.sender_id = u.id
            WHERE m.conversation_id = ? AND m.is_deleted = FALSE
            ORDER BY m.created_at DESC
            LIMIT ? OFFSET ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId, $limit, $offset]);
        
        $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Check payment status for contact revelation
        $contextResult = $conversation->getConversationContext($conversationId);
        $contactsRevealed = $this->areContactsRevealed($conversationId, $contextResult);

        // Process messages for contact masking and revelation
        foreach ($messages as &$message) {
            $message['contacts_revealed'] = $contactsRevealed;
            
            if (!$contactsRevealed && !$message['is_masked']) {
                $message = $this->maskContactsInMessage($message);
            }
            
            // Parse metadata
            if ($message['metadata']) {
                $message['metadata'] = json_decode($message['metadata'], true);
            }
            
            if ($message['system_data']) {
                $message['system_data'] = json_decode($message['system_data'], true);
            }
        }

        return array_reverse($messages); // Return in chronological order
    }

    public function markAsRead(int $messageId, int $userId): bool
    {
        $sql = "
            INSERT INTO message_reads (message_id, user_id, read_at) 
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE read_at = NOW()
        ";

        try {
            $stmt = $this->db->prepare($sql);
            return $stmt->execute([$messageId, $userId]);
        } catch (Exception $e) {
            return false;
        }
    }

    public function markConversationAsRead(int $conversationId, int $userId): int
    {
        $sql = "
            INSERT INTO message_reads (message_id, user_id, read_at)
            SELECT m.id, ?, NOW()
            FROM messages m
            LEFT JOIN message_reads mr ON m.id = mr.message_id AND mr.user_id = ?
            WHERE m.conversation_id = ? AND m.sender_id != ? AND mr.id IS NULL AND m.is_deleted = FALSE
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId, $userId, $conversationId, $userId]);
        
        return $stmt->rowCount();
    }

    private function moderateContent(string $content, string $type): array
    {
        $result = [
            'status' => self::MODERATION_APPROVED,
            'is_masked' => false,
            'flags' => []
        ];

        if ($type !== self::TYPE_TEXT) {
            return $result;
        }

        $flags = [];
        $maskedContent = $content;
        
        // Check for contact information
        foreach ($this->contactPatterns as $patternType => $pattern) {
            if (preg_match($pattern, $content)) {
                $flags[] = "contains_{$patternType}";
                $maskedContent = preg_replace($pattern, '[CONTACT MASQUÉ]', $maskedContent);
            }
        }

        // Check for suspicious keywords
        foreach ($this->suspiciousKeywords as $keyword) {
            if (stripos($content, $keyword) !== false) {
                $flags[] = 'suspicious_keyword_' . str_replace(' ', '_', $keyword);
            }
        }

        if (!empty($flags)) {
            $result['flags'] = $flags;
            
            // Mask content if contains contact info
            $contactFlags = array_filter($flags, function($flag) {
                return strpos($flag, 'contains_') === 0;
            });
            
            if (!empty($contactFlags)) {
                $result['is_masked'] = true;
                $result['masked_content'] = $maskedContent;
                $result['masking_reason'] = 'Coordonnées détectées - seront révélées après paiement';
            }
            
            // Flag suspicious content
            if (count($flags) > 2) {
                $result['status'] = self::MODERATION_FLAGGED;
            }
        }

        return $result;
    }

    private function areContactsRevealed(int $conversationId, ?array $context = null): bool
    {
        if (!$context) {
            $conversation = new Conversation();
            $context = $conversation->getConversationContext($conversationId);
        }

        if (!$context) {
            return false;
        }

        // Contacts are revealed after payment confirmation
        return $context['payment_confirmed'] === 'completed' || 
               $context['booking_status'] === 'completed';
    }

    private function maskContactsInMessage(array $message): array
    {
        if ($message['message_type'] !== self::TYPE_TEXT || $message['sender_id'] == 0) {
            return $message;
        }

        $content = $message['content'];
        $hasMasking = false;

        foreach ($this->contactPatterns as $pattern) {
            if (preg_match($pattern, $content)) {
                $content = preg_replace($pattern, '[CONTACT MASQUÉ]', $content);
                $hasMasking = true;
            }
        }

        if ($hasMasking) {
            $message['content'] = $content;
            $message['is_runtime_masked'] = true;
            $message['masking_notice'] = 'Les coordonnées seront révélées après confirmation du paiement';
        }

        return $message;
    }

    private function checkRateLimit(int $conversationId, int $senderId): bool
    {
        $sql = "
            SELECT message_count, window_start, is_limited, limited_until
            FROM message_rate_limits 
            WHERE user_id = ? AND conversation_id = ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$senderId, $conversationId]);
        $limit = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$limit) {
            return true; // No limit set yet
        }

        // Check if currently limited
        if ($limit['is_limited'] && $limit['limited_until'] && strtotime($limit['limited_until']) > time()) {
            return false;
        }

        // Reset window if needed (5 minutes)
        if (strtotime($limit['window_start']) < strtotime('-5 minutes')) {
            $this->resetRateLimit($senderId, $conversationId);
            return true;
        }

        // Check message count (max 20 messages per 5 minutes)
        return $limit['message_count'] < 20;
    }

    private function updateRateLimit(int $senderId, int $conversationId): void
    {
        $sql = "
            INSERT INTO message_rate_limits (user_id, conversation_id, message_count, window_start)
            VALUES (?, ?, 1, NOW())
            ON DUPLICATE KEY UPDATE 
                message_count = message_count + 1,
                is_limited = CASE WHEN message_count >= 19 THEN TRUE ELSE FALSE END,
                limited_until = CASE WHEN message_count >= 19 THEN DATE_ADD(NOW(), INTERVAL 10 MINUTE) ELSE NULL END
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$senderId, $conversationId]);
    }

    private function resetRateLimit(int $senderId, int $conversationId): void
    {
        $sql = "
            UPDATE message_rate_limits 
            SET message_count = 0, window_start = NOW(), is_limited = FALSE, limited_until = NULL
            WHERE user_id = ? AND conversation_id = ?
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$senderId, $conversationId]);
    }

    private function logModerationAction(int $messageId, string $action, string $reason, array $flags = []): void
    {
        $sql = "
            INSERT INTO message_moderation_logs (message_id, action, reason, detected_patterns, created_at)
            VALUES (?, ?, ?, ?, NOW())
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$messageId, $action, $reason, json_encode($flags)]);
    }

    public function deleteMessage(int $messageId, int $userId): bool
    {
        $sql = "
            UPDATE {$this->table} 
            SET is_deleted = TRUE, deleted_at = NOW(), deleted_by = ?
            WHERE id = ? AND sender_id = ?
        ";

        $stmt = $this->db->prepare($sql);
        return $stmt->execute([$userId, $messageId, $userId]);
    }

    public function getMessageStats(int $conversationId): array
    {
        $sql = "
            SELECT 
                COUNT(*) as total_messages,
                COUNT(CASE WHEN message_type = 'text' THEN 1 END) as text_messages,
                COUNT(CASE WHEN message_type = 'image' THEN 1 END) as image_messages,
                COUNT(CASE WHEN message_type = 'system' THEN 1 END) as system_messages,
                COUNT(CASE WHEN is_masked = TRUE THEN 1 END) as masked_messages,
                COUNT(CASE WHEN moderation_status = 'flagged' THEN 1 END) as flagged_messages
            FROM {$this->table}
            WHERE conversation_id = ? AND is_deleted = FALSE
        ";

        $stmt = $this->db->prepare($sql);
        $stmt->execute([$conversationId]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    }
}