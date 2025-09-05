<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Notification;
use KiloShare\Models\UserFCMToken;
use KiloShare\Services\FirebaseNotificationService;
use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class NotificationController
{
    public function getUserNotifications(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $unreadOnly = isset($queryParams['unread_only']) && $queryParams['unread_only'] === 'true';

            $query = Notification::where('user_id', $user->id);

            if ($unreadOnly) {
                $query->unread();
            }

            $notifications = $query->orderBy('created_at', 'desc')
                                  ->skip(($page - 1) * $limit)
                                  ->take($limit)
                                  ->get();

            $total = $query->count();
            $unreadCount = Notification::where('user_id', $user->id)->unread()->count();

            return Response::success([
                'notifications' => $notifications->map(function ($notification) {
                    return [
                        'id' => $notification->id,
                        'type' => $notification->type,
                        'title' => $notification->title,
                        'message' => $notification->message,
                        'data' => $notification->data,
                        'is_read' => $notification->is_read,
                        'read_at' => $notification->read_at,
                        'action_url' => $notification->action_url,
                        'created_at' => $notification->created_at,
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ],
                'unread_count' => $unreadCount,
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch notifications: ' . $e->getMessage());
        }
    }

    public function markAsRead(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $notificationId = $request->getAttribute('id');

        try {
            $notification = Notification::where('user_id', $user->id)
                                       ->find($notificationId);

            if (!$notification) {
                return Response::notFound('Notification not found');
            }

            $notification->markAsRead();

            return Response::success([
                'notification' => [
                    'id' => $notification->id,
                    'is_read' => $notification->is_read,
                    'read_at' => $notification->read_at,
                ]
            ], 'Notification marked as read');

        } catch (\Exception $e) {
            return Response::serverError('Failed to mark notification as read: ' . $e->getMessage());
        }
    }

    public function markAllAsRead(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            $updatedCount = Notification::where('user_id', $user->id)
                                       ->unread()
                                       ->update([
                                           'is_read' => true,
                                           'read_at' => now(),
                                       ]);

            return Response::success([
                'updated_count' => $updatedCount,
            ], 'All notifications marked as read');

        } catch (\Exception $e) {
            return Response::serverError('Failed to mark all notifications as read: ' . $e->getMessage());
        }
    }

    public function deleteNotification(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $notificationId = $request->getAttribute('id');

        try {
            $notification = Notification::where('user_id', $user->id)
                                       ->find($notificationId);

            if (!$notification) {
                return Response::notFound('Notification not found');
            }

            $notification->delete();

            return Response::success([
                'message' => 'Notification deleted successfully'
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to delete notification: ' . $e->getMessage());
        }
    }

    public function getUnreadCount(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            $unreadCount = Notification::where('user_id', $user->id)
                                     ->unread()
                                     ->count();

            return Response::success([
                'unread_count' => $unreadCount,
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get unread count: ' . $e->getMessage());
        }
    }

    public function getNotificationsByType(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $type = $request->getAttribute('type');

        try {
            $notifications = Notification::where('user_id', $user->id)
                                        ->byType($type)
                                        ->orderBy('created_at', 'desc')
                                        ->take(50)
                                        ->get();

            return Response::success([
                'notifications' => $notifications->map(function ($notification) {
                    return [
                        'id' => $notification->id,
                        'type' => $notification->type,
                        'title' => $notification->title,
                        'message' => $notification->message,
                        'data' => $notification->data,
                        'is_read' => $notification->is_read,
                        'created_at' => $notification->created_at,
                    ];
                }),
                'total' => $notifications->count(),
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch notifications by type: ' . $e->getMessage());
        }
    }

    public function registerFCMToken(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = $request->getParsedBody();

        try {
            $token = $data['token'] ?? null;
            $platform = $data['platform'] ?? 'mobile';
            $deviceInfo = $data['device_info'] ?? [];

            if (empty($token)) {
                return Response::validationError(['token' => 'FCM token is required']);
            }

            $firebaseService = new FirebaseNotificationService();
            $success = $firebaseService->registerToken($user->id, $token, $platform);

            if ($success) {
                if (!empty($deviceInfo)) {
                    UserFCMToken::where('user_id', $user->id)
                              ->where('fcm_token', $token)
                              ->update(['device_info' => $deviceInfo]);
                }

                return Response::success([
                    'message' => 'FCM token registered successfully',
                    'token' => $token
                ]);
            } else {
                return Response::serverError('Failed to register FCM token');
            }

        } catch (\Exception $e) {
            return Response::serverError('Error registering FCM token: ' . $e->getMessage());
        }
    }

    public function unregisterFCMToken(ServerRequestInterface $request): ResponseInterface
    {
        $data = $request->getParsedBody();

        try {
            $token = $data['token'] ?? null;

            if (empty($token)) {
                return Response::validationError(['token' => 'FCM token is required']);
            }

            $firebaseService = new FirebaseNotificationService();
            $success = $firebaseService->unregisterToken($token);

            if ($success) {
                return Response::success([
                    'message' => 'FCM token unregistered successfully'
                ]);
            } else {
                return Response::serverError('Failed to unregister FCM token');
            }

        } catch (\Exception $e) {
            return Response::serverError('Error unregistering FCM token: ' . $e->getMessage());
        }
    }

    public function sendTestNotification(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            $firebaseService = new FirebaseNotificationService();
            $success = $firebaseService->sendTestNotification($user->id);

            if ($success) {
                return Response::success([
                    'message' => 'Test notification sent successfully'
                ]);
            } else {
                return Response::serverError('Failed to send test notification');
            }

        } catch (\Exception $e) {
            return Response::serverError('Error sending test notification: ' . $e->getMessage());
        }
    }

    public function getFCMStats(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $firebaseService = new FirebaseNotificationService();
            $stats = $firebaseService->getTokenStats();

            return Response::success($stats);

        } catch (\Exception $e) {
            return Response::serverError('Error getting FCM stats: ' . $e->getMessage());
        }
    }
}