import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../config/app_config.dart';
import '../models/notification_model.dart';

class NotificationApiService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  final Dio _dio;

  NotificationApiService({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print(obj),
      ));
    }

    return dio;
  }

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<Options> _getAuthHeaders() async {
    final token = await _getAccessToken();
    return Options(
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  /// Enregistrer le token FCM
  Future<void> registerFCMToken(String token) async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Registering FCM token: $token');
      }

      final response = await _dio.post(
        '/user/notifications/register-token',
        data: {
          'fcm_token': token,
          'platform': 'mobile',
          'device_type': 'flutter',
        },
        options: await _getAuthHeaders(),
      );

      if (kDebugMode) {
        print('[NotificationApiService] FCM token registered: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error registering FCM token: $e');
      }
      rethrow;
    }
  }

  /// Récupérer les notifications de l'utilisateur
  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
    String? type,
  }) async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Getting notifications - page: $page, limit: $limit');
      }

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (isRead != null) queryParams['is_read'] = isRead ? 1 : 0;
      if (type != null) queryParams['type'] = type;

      final response = await _dio.get(
        '/user/notifications',
        queryParameters: queryParams,
        options: await _getAuthHeaders(),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final notificationsData = response.data['data']['notifications'] as List;
        return notificationsData
            .map((notification) => NotificationModel.fromJson(notification))
            .toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error getting notifications: $e');
      }
      rethrow;
    }
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(int notificationId) async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Marking notification as read: $notificationId');
      }

      final response = await _dio.put(
        '/user/notifications/$notificationId/read',
        options: await _getAuthHeaders(),
      );

      if (kDebugMode) {
        print('[NotificationApiService] Notification marked as read: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error marking notification as read: $e');
      }
      rethrow;
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Marking all notifications as read');
      }

      final response = await _dio.put(
        '/user/notifications/read-all',
        options: await _getAuthHeaders(),
      );

      if (kDebugMode) {
        print('[NotificationApiService] All notifications marked as read: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error marking all notifications as read: $e');
      }
      rethrow;
    }
  }

  /// Supprimer une notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Deleting notification: $notificationId');
      }

      final response = await _dio.delete(
        '/user/notifications/$notificationId',
        options: await _getAuthHeaders(),
      );

      if (kDebugMode) {
        print('[NotificationApiService] Notification deleted: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error deleting notification: $e');
      }
      rethrow;
    }
  }

  /// Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Getting unread notifications count');
      }

      final response = await _dio.get(
        '/user/notifications/unread-count',
        options: await _getAuthHeaders(),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final count = response.data['data']['count'] ?? 0;
        if (kDebugMode) {
          print('[NotificationApiService] Unread count: $count');
        }
        return count;
      }

      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Mettre à jour les préférences de notification
  Future<void> updateNotificationPreferences({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? tripUpdates,
    bool? bookingUpdates,
    bool? paymentUpdates,
    bool? messageUpdates,
    bool? promotionalUpdates,
  }) async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Updating notification preferences');
      }

      final data = <String, dynamic>{};
      if (pushNotifications != null) data['push_notifications'] = pushNotifications;
      if (emailNotifications != null) data['email_notifications'] = emailNotifications;
      if (smsNotifications != null) data['sms_notifications'] = smsNotifications;
      if (tripUpdates != null) data['trip_updates'] = tripUpdates;
      if (bookingUpdates != null) data['booking_updates'] = bookingUpdates;
      if (paymentUpdates != null) data['payment_updates'] = paymentUpdates;
      if (messageUpdates != null) data['message_updates'] = messageUpdates;
      if (promotionalUpdates != null) data['promotional_updates'] = promotionalUpdates;

      final response = await _dio.put(
        '/user/notifications/preferences',
        data: data,
        options: await _getAuthHeaders(),
      );

      if (kDebugMode) {
        print('[NotificationApiService] Preferences updated: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error updating preferences: $e');
      }
      rethrow;
    }
  }

  /// Récupérer les préférences de notification
  Future<Map<String, bool>> getNotificationPreferences() async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Getting notification preferences');
      }

      final response = await _dio.get(
        '/user/notifications/preferences',
        options: await _getAuthHeaders(),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final preferences = response.data['data']['preferences'];
        return {
          'push_notifications': preferences['push_notifications'] == 1,
          'email_notifications': preferences['email_notifications'] == 1,
          'sms_notifications': preferences['sms_notifications'] == 1,
          'trip_updates': preferences['trip_updates'] == 1,
          'booking_updates': preferences['booking_updates'] == 1,
          'payment_updates': preferences['payment_updates'] == 1,
          'message_updates': preferences['message_updates'] == 1,
          'promotional_updates': preferences['promotional_updates'] == 1,
        };
      }

      return {};
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error getting preferences: $e');
      }
      return {};
    }
  }

  /// Envoyer une notification de test
  Future<void> sendTestNotification() async {
    try {
      if (kDebugMode) {
        print('[NotificationApiService] Sending test notification');
      }

      final response = await _dio.post(
        '/user/notifications/test',
        options: await _getAuthHeaders(),
      );

      if (kDebugMode) {
        print('[NotificationApiService] Test notification sent: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationApiService] Error sending test notification: $e');
      }
      rethrow;
    }
  }
}