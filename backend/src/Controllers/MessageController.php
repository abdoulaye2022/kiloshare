<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Booking;
use KiloShare\Models\Message;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class MessageController
{
    public function getBookingMessages(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $bookingId = $request->getAttribute('id');

        try {
            $booking = Booking::with('trip')->find($bookingId);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if ($booking->user_id !== $user->id && $booking->trip->user_id !== $user->id) {
                return Response::forbidden('Access denied');
            }

            $messages = Message::forBooking($bookingId)
                              ->with(['sender', 'receiver'])
                              ->orderBy('created_at', 'asc')
                              ->get();

            // Marquer les messages reçus comme lus
            Message::forBooking($bookingId)
                   ->where('receiver_id', $user->id)
                   ->where('is_read', false)
                   ->update(['is_read' => true, 'read_at' => now()]);

            return Response::success([
                'messages' => $messages->map(function ($message) {
                    return [
                        'id' => $message->id,
                        'content' => $message->content,
                        'message_type' => $message->message_type,
                        'attachment_url' => $message->attachment_url,
                        'is_read' => $message->is_read,
                        'created_at' => $message->created_at,
                        'sender' => [
                            'id' => $message->sender->id,
                            'first_name' => $message->sender->first_name,
                            'profile_picture' => $message->sender->profile_picture,
                        ],
                    ];
                }),
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'status' => $booking->status,
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch messages: ' . $e->getMessage());
        }
    }

    public function sendMessage(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $bookingId = $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'content' => Validator::required()->stringType()->length(1, 1000),
            'message_type' => Validator::optional(Validator::stringType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $booking = Booking::with('trip')->find($bookingId);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if ($booking->user_id !== $user->id && $booking->trip->user_id !== $user->id) {
                return Response::forbidden('Access denied');
            }

            $receiverId = $booking->user_id === $user->id ? $booking->trip->user_id : $booking->user_id;

            $message = Message::create([
                'booking_id' => $bookingId,
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
                'content' => $data['content'],
                'message_type' => $data['message_type'] ?? 'text',
            ]);

            return Response::created([
                'message' => [
                    'id' => $message->id,
                    'content' => $message->content,
                    'message_type' => $message->message_type,
                    'created_at' => $message->created_at,
                ]
            ], 'Message sent successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to send message: ' . $e->getMessage());
        }
    }

    public function getUserConversations(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            // Récupérer toutes les conversations de l'utilisateur
            $conversations = Message::where('sender_id', $user->id)
                                   ->orWhere('receiver_id', $user->id)
                                   ->with(['booking.trip', 'sender', 'receiver'])
                                   ->orderBy('created_at', 'desc')
                                   ->get()
                                   ->groupBy('booking_id')
                                   ->map(function ($messages) use ($user) {
                                       $latestMessage = $messages->first();
                                       $otherUser = $latestMessage->sender_id === $user->id 
                                           ? $latestMessage->receiver 
                                           : $latestMessage->sender;
                                       
                                       $unreadCount = $messages->where('receiver_id', $user->id)
                                                               ->where('is_read', false)
                                                               ->count();

                                       return [
                                           'booking_id' => $latestMessage->booking_id,
                                           'booking' => [
                                               'uuid' => $latestMessage->booking->uuid,
                                               'status' => $latestMessage->booking->status,
                                               'trip' => [
                                                   'title' => $latestMessage->booking->trip->title,
                                                   'departure_city' => $latestMessage->booking->trip->departure_city,
                                                   'arrival_city' => $latestMessage->booking->trip->arrival_city,
                                               ],
                                           ],
                                           'other_user' => [
                                               'id' => $otherUser->id,
                                               'first_name' => $otherUser->first_name,
                                               'profile_picture' => $otherUser->profile_picture,
                                           ],
                                           'latest_message' => [
                                               'content' => $latestMessage->content,
                                               'created_at' => $latestMessage->created_at,
                                               'is_from_me' => $latestMessage->sender_id === $user->id,
                                           ],
                                           'unread_count' => $unreadCount,
                                       ];
                                   })
                                   ->values();

            return Response::success([
                'conversations' => $conversations,
                'total' => $conversations->count(),
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch conversations: ' . $e->getMessage());
        }
    }

    public function markAsRead(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $messageId = $request->getAttribute('id');

        try {
            $message = Message::find($messageId);

            if (!$message) {
                return Response::notFound('Message not found');
            }

            if ($message->receiver_id !== $user->id) {
                return Response::forbidden('Access denied');
            }

            $message->markAsRead();

            return Response::success([
                'message' => [
                    'id' => $message->id,
                    'is_read' => $message->is_read,
                    'read_at' => $message->read_at,
                ]
            ], 'Message marked as read');

        } catch (\Exception $e) {
            return Response::serverError('Failed to mark message as read: ' . $e->getMessage());
        }
    }
}