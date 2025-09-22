<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\ConversationModel;
use KiloShare\Models\MessageModel;
use KiloShare\Services\SmartNotificationService;
use KiloShare\Utils\Database;
use Exception;
use PDO;

class MessagingService
{
    private ConversationModel $conversationModel;
    private MessageModel $messageModel;
    private SmartNotificationService $notificationService;
    private PDO $db;

    public function __construct()
    {
        $this->conversationModel = new ConversationModel();
        $this->messageModel = new MessageModel();
        $this->notificationService = new SmartNotificationService();
        $this->db = Database::getConnection()->getPdo();
    }

    public function createOrGetConversation(int $bookingId, int $userId): ?array
    {
        // Check if conversation already exists
        $conversation = $this->conversationModel->findByBooking($bookingId);
        
        if ($conversation) {
            // Verify user is participant
            if (!$this->conversationModel->isParticipant($conversation['id'], $userId)) {
                throw new Exception('Access denied');
            }
            return $conversation;
        }

        // Get booking details to create conversation
        $booking = $this->getBookingDetails($bookingId);
        if (!$booking) {
            throw new Exception('Booking not found');
        }

        // Verify user is part of this booking
        if ($booking['driver_id'] !== $userId && $booking['user_id'] !== $userId) {
            throw new Exception('Access denied');
        }

        // Create new conversation
        $conversationId = $this->conversationModel->createConversation($bookingId);
        
        // Add participants
        $this->conversationModel->addParticipant($conversationId, $booking['driver_id'], 'driver');
        $this->conversationModel->addParticipant($conversationId, $booking['user_id'], 'passenger');

        // Send system welcome message
        $this->messageModel->sendSystemMessage(
            $conversationId,
            'conversation_started',
            ['booking_id' => $bookingId],
            'Conversation démarrée pour cette réservation'
        );

        return $this->conversationModel->findById($conversationId);
    }

    public function sendMessage(
        int $conversationId,
        int $senderId,
        string $content,
        string $type = MessageModel::TYPE_TEXT,
        array $metadata = []
    ): array {
        try {
            // Verify sender is participant
            if (!$this->conversationModel->isParticipant($conversationId, $senderId)) {
                throw new Exception('Access denied');
            }

            // Get conversation context
            $context = $this->conversationModel->getConversationContext($conversationId);
            if (!$context) {
                throw new Exception('Conversation not found');
            }

            // Send message
            $result = $this->messageModel->sendMessage(
                $conversationId,
                $senderId,
                $content,
                $type,
                $metadata
            );

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to send message');
            }

            $messageId = $result['message_id'];

            // Get recipient for notifications
            $participants = $this->conversationModel->getParticipants($conversationId);
            $recipient = null;
            
            foreach ($participants as $participant) {
                if ($participant['user_id'] !== $senderId) {
                    $recipient = $participant;
                    break;
                }
            }

            // Send notification to recipient
            if ($recipient) {
                $this->notificationService->send(
                    $recipient['user_id'],
                    'new_message',
                    [
                        'sender_name' => $this->getUserName($senderId),
                        'message_preview' => $this->getMessagePreview($content, $type),
                        'conversation_id' => $conversationId,
                        'booking_id' => $context['booking_id']
                    ],
                    [
                        'scope' => 'conversation',
                        'scope_id' => $conversationId,
                        'channels' => ['push', 'in_app']
                    ]
                );
            }

            return [
                'success' => true,
                'message_id' => $messageId,
                'conversation_id' => $conversationId
            ];

        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    public function sendQuickAction(
        int $conversationId,
        int $senderId,
        string $actionType,
        array $actionData
    ): array {
        try {
            // Verify access
            if (!$this->conversationModel->isParticipant($conversationId, $senderId)) {
                throw new Exception('Access denied');
            }

            $context = $this->conversationModel->getConversationContext($conversationId);
            if (!$context) {
                throw new Exception('Conversation not found');
            }

            // Create action message
            $messageId = $this->messageModel->sendMessage(
                $conversationId,
                $senderId,
                $this->getActionMessageContent($actionType, $actionData),
                MessageModel::TYPE_ACTION,
                ['action_type' => $actionType, 'action_data' => $actionData]
            );

            // Store quick action
            $this->storeQuickAction($messageId, $actionType, $actionData);

            // Process the action
            $result = $this->processQuickAction($context['booking_id'], $actionType, $actionData);

            // Send system confirmation message
            if ($result['success']) {
                $this->messageModel->sendSystemMessage(
                    $conversationId,
                    $actionType . '_processed',
                    $result,
                    $this->getSystemActionMessage($actionType, $result)
                );
            }

            return [
                'success' => true,
                'message_id' => $messageId,
                'action_result' => $result
            ];

        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    public function shareLocation(
        int $conversationId,
        int $senderId,
        float $latitude,
        float $longitude,
        ?string $address = null
    ): array {
        try {
            // Verify this is post-payment conversation or day of travel
            $context = $this->conversationModel->getConversationContext($conversationId);
            if (!$this->canShareLocation($context)) {
                throw new Exception('Location sharing not allowed at this stage');
            }

            $locationData = [
                'latitude' => $latitude,
                'longitude' => $longitude,
                'address' => $address,
                'shared_at' => date('c')
            ];

            $messageId = $this->messageModel->sendMessage(
                $conversationId,
                $senderId,
                $address ? "Position partagée: {$address}" : "Position partagée",
                MessageModel::TYPE_LOCATION,
                $locationData
            );

            return [
                'success' => true,
                'message_id' => $messageId
            ];

        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    public function sharePhoto(
        int $conversationId,
        int $senderId,
        string $photoPath,
        ?string $caption = null
    ): array {
        try {
            // Verify this is post-payment conversation
            $context = $this->conversationModel->getConversationContext($conversationId);
            if (!$this->canSharePhotos($context)) {
                throw new Exception('Photo sharing not allowed before payment confirmation');
            }

            // Verify and process photo
            $photoData = $this->processPhotoUpload($photoPath);
            if (!$photoData) {
                throw new Exception('Invalid photo');
            }

            $messageId = $this->messageModel->sendMessage(
                $conversationId,
                $senderId,
                $caption ?: 'Photo partagée',
                MessageModel::TYPE_IMAGE,
                $photoData
            );

            // Store attachment record
            $this->storeAttachment($messageId, $photoData);

            return [
                'success' => true,
                'message_id' => $messageId,
                'photo_data' => $photoData
            ];

        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    public function upgradeConversationToPostPayment(int $bookingId): ?array
    {
        try {
            $conversationId = $this->conversationModel->upgradeToPostPayment($bookingId);
            
            if ($conversationId) {
                // Send system message about contact revelation
                $this->messageModel->sendSystemMessage(
                    $conversationId,
                    'contacts_revealed',
                    ['booking_id' => $bookingId],
                    '🎉 Paiement confirmé ! Les coordonnées sont maintenant visibles et vous pouvez partager des photos.'
                );

                // Log contact revelation
                $this->logContactRevelation($conversationId, $bookingId);
            }

            return $this->conversationModel->findById($conversationId);

        } catch (Exception $e) {
            return null;
        }
    }

    private function getBookingDetails(int $bookingId): ?array
    {
        global $pdo;
        $sql = "
            SELECT b.*, t.title, t.departure_date 
            FROM bookings b 
            INNER JOIN trips t ON b.trip_id = t.id 
            WHERE b.id = ?
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$bookingId]);
        return $stmt->fetch(\PDO::FETCH_ASSOC) ?: null;
    }

    private function getUserName(int $userId): string
    {
        $sql = "SELECT first_name, last_name FROM users WHERE id = ?";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $user ? $user['first_name'] . ' ' . $user['last_name'] : 'Utilisateur';
    }

    private function getMessagePreview(string $content, string $type): string
    {
        switch ($type) {
            case MessageModel::TYPE_IMAGE:
                return '📷 Photo';
            case MessageModel::TYPE_LOCATION:
                return '📍 Position';
            case MessageModel::TYPE_ACTION:
                return '⚡ Action rapide';
            case MessageModel::TYPE_SYSTEM:
                return '🤖 Message système';
            default:
                return substr($content, 0, 100);
        }
    }

    private function getActionMessageContent(string $actionType, array $actionData): string
    {
        switch ($actionType) {
            case 'accept_booking':
                return "✅ J'accepte cette réservation";
            case 'reject_booking':
                return "❌ Je refuse cette réservation";
            case 'counter_offer':
                return "💰 Contre-proposition: {$actionData['price']}€";
            case 'accept_price':
                return "✅ J'accepte ce prix: {$actionData['price']}€";
            case 'reject_price':
                return "❌ Je refuse ce prix";
            default:
                return "Action: {$actionType}";
        }
    }

    private function getSystemActionMessage(string $actionType, array $result): string
    {
        switch ($actionType) {
            case 'accept_booking':
                return "✅ Réservation acceptée ! Procédez maintenant au paiement.";
            case 'reject_booking':
                return "❌ Réservation refusée.";
            case 'counter_offer':
                return "💰 Contre-proposition envoyée. En attente de réponse.";
            case 'accept_price':
                return "✅ Prix accepté ! Procédez maintenant au paiement.";
            case 'reject_price':
                return "❌ Prix refusé. Vous pouvez faire une autre proposition.";
            default:
                return "Action traitée.";
        }
    }

    private function canShareLocation(array $context): bool
    {
        // Location can be shared post-payment or on day of travel
        return $context['payment_confirmed'] === 'completed' ||
               ($context['departure_date'] && date('Y-m-d') === date('Y-m-d', strtotime($context['departure_date'])));
    }

    private function canSharePhotos(array $context): bool
    {
        // Photos only after payment confirmation
        return $context['payment_confirmed'] === 'completed';
    }

    private function storeQuickAction(int $messageId, string $actionType, array $actionData): void
    {
        global $pdo;
        $sql = "
            INSERT INTO message_quick_actions (message_id, action_type, action_data, expires_at)
            VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$messageId, $actionType, json_encode($actionData)]);
    }

    private function storeAttachment(int $messageId, array $photoData): void
    {
        global $pdo;
        $sql = "
            INSERT INTO message_attachments (message_id, file_name, file_path, file_type, file_size, image_width, image_height, thumbnail_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            $messageId,
            $photoData['file_name'],
            $photoData['file_path'],
            $photoData['file_type'],
            $photoData['file_size'],
            $photoData['image_width'] ?? null,
            $photoData['image_height'] ?? null,
            $photoData['thumbnail_path'] ?? null
        ]);
    }

    private function logContactRevelation(int $conversationId, int $bookingId): void
    {
        global $pdo;
        $sql = "
            INSERT INTO contact_revelations (conversation_id, booking_id, phone_revealed, email_revealed, full_name_revealed)
            VALUES (?, ?, TRUE, TRUE, TRUE)
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$conversationId, $bookingId]);
    }

    private function processQuickAction(int $bookingId, string $actionType, array $actionData): array
    {
        // This would integrate with your booking system
        // For now, return a mock response
        return [
            'success' => true,
            'booking_id' => $bookingId,
            'action' => $actionType,
            'data' => $actionData
        ];
    }

    private function processPhotoUpload(string $photoPath): ?array
    {
        // Mock photo processing - implement actual upload logic
        if (!file_exists($photoPath)) {
            return null;
        }

        return [
            'file_name' => basename($photoPath),
            'file_path' => $photoPath,
            'file_type' => mime_content_type($photoPath),
            'file_size' => filesize($photoPath),
            'image_width' => 800,
            'image_height' => 600,
            'thumbnail_path' => $photoPath . '_thumb.jpg'
        ];
    }
}