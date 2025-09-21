<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Booking;
use KiloShare\Models\ConversationModel;
use KiloShare\Models\MessageModel;
use KiloShare\Services\MessagingService;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class MessageController
{
    private MessagingService $messagingService;

    public function __construct()
    {
        $this->messagingService = new MessagingService();
    }

    public function getConversations(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $queryParams = $request->getQueryParams();

        try {
            $limit = min((int)($queryParams['limit'] ?? 20), 50);
            $offset = (int)($queryParams['offset'] ?? 0);

            $conversationModel = new ConversationModel();
            $conversations = $conversationModel->getUserConversations($user->id, $limit, $offset);

            return Response::success([
                'conversations' => $conversations,
                'total_unread' => count($conversations) // TODO: Implement proper unread count
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch conversations: ' . $e->getMessage());
        }
    }

    public function getConversationMessages(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $conversationId = (int)$request->getAttribute('id');
        $queryParams = $request->getQueryParams();

        try {
            $limit = min((int)($queryParams['limit'] ?? 50), 100);
            $offset = (int)($queryParams['offset'] ?? 0);

            $messageModel = new MessageModel();
            $messages = $messageModel->getConversationMessages($conversationId, $user->id, $limit, $offset);

            // Mark messages as read
            $messageModel->markConversationAsRead($conversationId, $user->id);

            return Response::success([
                'messages' => $messages
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch messages: ' . $e->getMessage());
        }
    }

    public function getBookingMessages(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $bookingId = (int)$request->getAttribute('id');

        try {
            // Get or create conversation for this booking
            $conversation = $this->messagingService->createOrGetConversation($bookingId, $user->id);
            
            if (!$conversation) {
                return Response::serverError('Failed to access conversation');
            }

            // Get messages for this conversation
            $messageModel = new MessageModel();
            $messages = $messageModel->getConversationMessages($conversation['id'], $user->id);

            // Mark messages as read
            $messageModel->markConversationAsRead($conversation['id'], $user->id);

            return Response::success([
                'conversation' => $conversation,
                'messages' => $messages
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch messages: ' . $e->getMessage());
        }
    }

    public function sendMessage(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            if (empty($data['content'])) {
                return Response::validationError(['content' => 'Message content is required']);
            }

            if (strlen($data['content']) > 1000) {
                return Response::validationError(['content' => 'Message too long (max 1000 characters)']);
            }

            $conversationId = (int)($data['conversation_id'] ?? 0);
            $bookingId = (int)($data['booking_id'] ?? 0);

            // Handle both conversation and booking based messaging
            if ($conversationId) {
                $result = $this->messagingService->sendMessage(
                    $conversationId,
                    $user->id,
                    $data['content'],
                    $data['message_type'] ?? MessageModel::TYPE_TEXT,
                    $data['metadata'] ?? []
                );
            } elseif ($bookingId) {
                $conversation = $this->messagingService->createOrGetConversation($bookingId, $user->id);
                if (!$conversation) {
                    return Response::serverError('Failed to create conversation');
                }
                
                $result = $this->messagingService->sendMessage(
                    $conversation['id'],
                    $user->id,
                    $data['content'],
                    $data['message_type'] ?? MessageModel::TYPE_TEXT,
                    $data['metadata'] ?? []
                );
            } else {
                return Response::validationError(['conversation_id' => 'Conversation ID or Booking ID required']);
            }

            if ($result['success']) {
                return Response::success($result);
            } else {
                return Response::serverError($result['error'] ?? 'Failed to send message');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to send message: ' . $e->getMessage());
        }
    }

    public function sendQuickAction(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $conversationId = (int)$request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            if (empty($data['action_type'])) {
                return Response::validationError(['action_type' => 'Action type is required']);
            }

            $result = $this->messagingService->sendQuickAction(
                $conversationId,
                $user->id,
                $data['action_type'],
                $data['action_data'] ?? []
            );

            if ($result['success']) {
                return Response::success($result);
            } else {
                return Response::serverError($result['error'] ?? 'Failed to process action');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to process action: ' . $e->getMessage());
        }
    }

    public function shareLocation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $conversationId = (int)$request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            if (empty($data['latitude']) || empty($data['longitude'])) {
                return Response::validationError(['location' => 'Latitude and longitude are required']);
            }

            $result = $this->messagingService->shareLocation(
                $conversationId,
                $user->id,
                (float)$data['latitude'],
                (float)$data['longitude'],
                $data['address'] ?? null
            );

            if ($result['success']) {
                return Response::success($result);
            } else {
                return Response::serverError($result['error'] ?? 'Failed to share location');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to share location: ' . $e->getMessage());
        }
    }

    public function sharePhoto(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $conversationId = (int)$request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            if (empty($data['photo_path'])) {
                return Response::validationError(['photo_path' => 'Photo path is required']);
            }

            $result = $this->messagingService->sharePhoto(
                $conversationId,
                $user->id,
                $data['photo_path'],
                $data['caption'] ?? null
            );

            if ($result['success']) {
                return Response::success($result);
            } else {
                return Response::serverError($result['error'] ?? 'Failed to share photo');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to share photo: ' . $e->getMessage());
        }
    }

    public function markAsRead(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $messageId = (int)$request->getAttribute('id');

        try {
            $messageModel = new MessageModel();
            $success = $messageModel->markAsRead($messageId, $user->id);

            if ($success) {
                return Response::success(['message' => 'Message marked as read']);
            } else {
                return Response::serverError('Failed to mark message as read');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to mark message as read: ' . $e->getMessage());
        }
    }

    public function deleteMessage(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $messageId = (int)$request->getAttribute('id');

        try {
            $messageModel = new MessageModel();
            $success = $messageModel->deleteMessage($messageId, $user->id);

            if ($success) {
                return Response::success(['message' => 'Message deleted']);
            } else {
                return Response::serverError('Failed to delete message');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to delete message: ' . $e->getMessage());
        }
    }

    public function getConversationStats(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $conversationId = (int)$request->getAttribute('id');

        try {
            // Verify user is participant
            $conversation = new ConversationModel();
            if (!$conversation->isParticipant($conversationId, $user->id)) {
                return Response::forbidden('Access denied');
            }

            $messageModel = new MessageModel();
            $stats = $messageModel->getMessageStats($conversationId);

            return Response::success(['stats' => $stats]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get stats: ' . $e->getMessage());
        }
    }

    /**
     * Create or get conversation for a trip
     */
    public function createOrGetConversation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            if (empty($data['trip_id']) || empty($data['trip_owner_id'])) {
                return Response::validationError([
                    'trip_id' => 'Trip ID is required',
                    'trip_owner_id' => 'Trip owner ID is required'
                ]);
            }

            $tripId = (int)$data['trip_id'];
            $tripOwnerId = (int)$data['trip_owner_id'];

            // Don't allow self-conversation
            if ($user->id == $tripOwnerId) {
                return Response::validationError(['error' => 'Cannot create conversation with yourself']);
            }

            $conversation = new ConversationModel();
            $result = $conversation->getOrCreateForTrip($tripId, $user->id, $tripOwnerId);

            if ($result) {
                return Response::success([
                    'conversation' => $result,
                    'message' => 'Conversation ready'
                ]);
            } else {
                return Response::serverError('Failed to create or get conversation');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to create conversation: ' . $e->getMessage());
        }
    }

    /**
     * Send message to conversation
     */
    public function sendConversationMessage(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $conversationId = (int)$request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        error_log("sendConversationMessage - User: " . ($user ? $user->id : 'null'));
        error_log("sendConversationMessage - ConversationId: " . $conversationId);
        error_log("sendConversationMessage - Data: " . json_encode($data));

        try {
            if (empty($data['content'])) {
                return Response::validationError(['content' => 'Message content is required']);
            }

            if (strlen($data['content']) > 1000) {
                return Response::validationError(['content' => 'Message too long (max 1000 characters)']);
            }

            // Verify user is participant
            $conversation = new ConversationModel();
            if (!$conversation->isParticipant($conversationId, $user->id)) {
                return Response::forbidden('Access denied');
            }

            $result = $this->messagingService->sendMessage(
                $conversationId,
                $user->id,
                $data['content'],
                $data['message_type'] ?? MessageModel::TYPE_TEXT,
                $data['metadata'] ?? []
            );

            if ($result['success']) {
                return Response::success($result);
            } else {
                return Response::serverError($result['error'] ?? 'Failed to send message');
            }

        } catch (\Exception $e) {
            return Response::serverError('Failed to send message: ' . $e->getMessage());
        }
    }
}