import 'dart:convert';
import '../../../utils/platform_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_api_service.dart';

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final NotificationApiService _notificationApiService = NotificationApiService();
  
  bool _isInitialized = false;
  String? _fcmToken;
  BuildContext? _context;

  // Getters
  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;
  
  /// Obtenir le token FCM
  Future<String?> getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        await _storage.write(key: 'fcm_token', value: _fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('Erreur lors de l\'obtention du token FCM: $e');
      return null;
    }
  }

  /// Initialiser le service de notifications
  Future<void> initialize({BuildContext? context}) async {
    if (_isInitialized) return;

    _context = context;
    
    try {
      // Initialiser Firebase si ce n'est pas fait
      await Firebase.initializeApp();

      // Demander les permissions
      await requestPermissions();

      // Configurer les notifications locales
      await _configureLocalNotifications();

      // Obtenir le token FCM
      await _getFCMToken();

      // Configurer les handlers de messages
      await _configureMessageHandlers();

      _isInitialized = true;

    } catch (e) {
      rethrow;
    }
  }

  /// Demander les permissions de notification
  Future<bool> requestPermissions() async {
    if (PlatformHelper.isAndroid) {
      // Permissions Android 13+
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (PlatformHelper.isIOS) {
      // Permissions iOS
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }
    return false;
  }

  /// Configurer les notifications locales
  Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer le canal de notification Android
    if (PlatformHelper.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Créer les canaux de notification Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notifications importantes',
      description: 'Canal pour les notifications importantes de KiloShare',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel normalImportanceChannel = AndroidNotificationChannel(
      'normal_importance_channel',
      'Notifications générales',
      description: 'Canal pour les notifications générales de KiloShare',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highImportanceChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(normalImportanceChannel);
  }

  /// Obtenir le token FCM
  Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        await _storage.write(key: 'fcm_token', value: token);
        
        // Envoyer le token au backend
        await _sendTokenToBackend(token);
      }

      // Écouter les changements de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await _storage.write(key: 'fcm_token', value: newToken);
        await _sendTokenToBackend(newToken);
      });
    } catch (e) {
    }
  }

  /// Envoyer le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _notificationApiService.registerFCMToken(token);
    } catch (e) {
    }
  }

  /// Configurer les handlers de messages
  Future<void> _configureMessageHandlers() async {
    // Messages reçus quand l'app est en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Messages qui ont ouvert l'app (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Vérifier si l'app a été ouverte via une notification (terminated)
    final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  /// Afficher une notification locale (publique pour les tests)
  Future<void> showLocalNotification(String title, String body, {String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Notifications de test',
      channelDescription: 'Notifications de test KiloShare',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Afficher une notification locale (privée)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Déterminer le canal et l'importance
      final priority = data['priority'] ?? 'normal';
      final channelId = priority == 'high' || priority == 'urgent'
          ? 'high_importance_channel'
          : 'normal_importance_channel';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'high_importance_channel' 
            ? 'Notifications importantes' 
            : 'Notifications générales',
        channelDescription: 'Notifications KiloShare',
        importance: channelId == 'high_importance_channel' 
            ? Importance.high 
            : Importance.defaultImportance,
        priority: channelId == 'high_importance_channel' 
            ? Priority.high 
            : Priority.defaultPriority,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: data['image_url'] != null 
            ? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher') 
            : null,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        message.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode(data),
      );
    }
  }

  /// Gérer le tap sur une notification locale
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationTap(data);
      } catch (e) {
      }
    }
  }

  /// Gérer le tap sur une notification (navigation)
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (_context == null) return;

    try {
      final type = data['type'] as String?;
      final actionUrl = data['action_url'] as String?;
      final tripId = data['trip_id'] as String?;
      final bookingId = data['booking_id'] as String?;

      if (actionUrl != null) {
        // Navigation personnalisée via URL
        GoRouter.of(_context!).push(actionUrl);
      } else if (type != null) {
        // Navigation basée sur le type
        switch (type) {
          case 'trip_booked':
          case 'trip_confirmed':
          case 'trip_cancelled':
            if (tripId != null) {
              GoRouter.of(_context!).push('/trips/$tripId');
            }
            break;
          case 'booking_confirmed':
          case 'booking_cancelled':
            if (bookingId != null) {
              GoRouter.of(_context!).push('/bookings/$bookingId');
            }
            break;
          case 'message_received':
            GoRouter.of(_context!).push('/messages');
            break;
          case 'payment_received':
          case 'payment_processed':
            GoRouter.of(_context!).push('/wallet');
            break;
          default:
            GoRouter.of(_context!).push('/notifications');
            break;
        }
      } else {
        // Navigation par défaut vers la liste des notifications
        GoRouter.of(_context!).push('/notifications');
      }
    } catch (e) {
      // Fallback vers les notifications
      GoRouter.of(_context!).push('/notifications');
    }
  }

  /// Marquer une notification comme lue
  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      await _notificationApiService.markAsRead(notificationId);
    } catch (e) {
    }
  }

  /// Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    try {
      return await _notificationApiService.getUnreadCount();
    } catch (e) {
      return 0;
    }
  }

  /// S'abonner à un topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
    } catch (e) {
    }
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
    }
  }

  /// Effacer toutes les notifications locales
  Future<void> clearAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Effacer une notification spécifique
  Future<void> clearNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Dispose des ressources
  void dispose() {
    // Cleanup si nécessaire
  }
}

/// Handler pour les messages en background (doit être une fonction top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  
  // Traitement des messages en background si nécessaire
}