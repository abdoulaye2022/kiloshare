import 'dart:convert';
import '../../../utils/platform_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
      // Firebase est déjà initialisé dans main.dart
      
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
    debugPrint('🔔 Demande des permissions de notifications...');
    
    if (PlatformHelper.isAndroid) {
      // Permissions Android 13+
      final status = await Permission.notification.request();
      debugPrint('🔔 Permissions Android: ${status.isGranted ? "Accordées" : "Refusées"}');
      return status.isGranted;
    } else if (PlatformHelper.isIOS) {
      // Permissions iOS
      debugPrint('🔔 Demande des permissions iOS...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      
      debugPrint('🔔 Status permission iOS: ${settings.authorizationStatus}');
      debugPrint('🔔 Alert: ${settings.alert}');
      debugPrint('🔔 Badge: ${settings.badge}');
      debugPrint('🔔 Sound: ${settings.sound}');
      
      bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;
      debugPrint('🔔 Permissions iOS: ${isAuthorized ? "Accordées" : "Refusées"}');
      return isAuthorized;
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
      debugPrint('🔥 Génération du token FCM...');
      
      // Sur iOS, attendre le token APNS avant de demander le token FCM
      if (PlatformHelper.isIOS) {
        debugPrint('🔥 iOS détecté - Vérification des permissions...');
        
        // Vérifier le statut des permissions actuelles
        final settings = await _firebaseMessaging.getNotificationSettings();
        debugPrint('🔔 Statut actuel des permissions: ${settings.authorizationStatus}');
        
        if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
          debugPrint('🔔 Permissions non déterminées - Demande en cours...');
          bool permissionsGranted = await requestPermissions();
          if (!permissionsGranted) {
            debugPrint('🔔 ❌ Permissions refusées par l\'utilisateur');
            return;
          }
        } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('🔔 ❌ Permissions refusées - Impossible de générer token FCM');
          debugPrint('🔔 💡 Allez dans Réglages > App > Notifications pour activer');
          return;
        }
        
        debugPrint('🔥 Tentative d\'obtention du token APNS...');
        
        // Essayer d'obtenir le token APNS
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        
        if (apnsToken != null) {
          debugPrint('🔥 Token APNS obtenu: ${apnsToken.substring(0, 20)}...');
        } else {
          debugPrint('🔥 ⚠️ Aucun token APNS disponible');
          debugPrint('🔥 ⚠️ CAUSES POSSIBLES:');
          debugPrint('🔥 ⚠️ 1. Test sur simulateur iOS (non supporté)');
          debugPrint('🔥 ⚠️ 2. Configuration APNS manquante dans Firebase Console');
          debugPrint('🔥 ⚠️ 3. Permissions notifications non accordées');
          debugPrint('🔥 ⚠️ 4. Premier lancement - permissions en attente');
          debugPrint('🔥 ⚠️ SOLUTION: Utilisez un appareil iOS réel ou Android');
          return;
        }
      }
      
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('🔥 Token FCM généré: ${token.substring(0, 20)}...');
        _fcmToken = token;
        await _storage.write(key: 'fcm_token', value: token);
        
        // Envoyer le token au backend
        await _sendTokenToBackend(token);
      } else {
        debugPrint('🔥 Erreur: Aucun token FCM généré');
      }

      // Écouter les changements de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔥 Token FCM rafraîchi: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
        await _storage.write(key: 'fcm_token', value: newToken);
        await _sendTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('🔥 Erreur lors de la génération du token FCM: $e');
    }
  }

  /// Envoyer le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      debugPrint('🔥 Envoi du token FCM au backend: ${token.substring(0, 20)}...');
      await _notificationApiService.registerFCMToken(token);
      debugPrint('🔥 Token FCM envoyé avec succès au backend');
    } catch (e) {
      debugPrint('🔥 Erreur lors de l\'envoi du token FCM: $e');
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
        // Ignore les erreurs de parsing des données de notification
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
      // Ignore les erreurs de marquage comme lue
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
      // Ignore les erreurs d'abonnement au topic
    }
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
      // Ignore les erreurs de désabonnement du topic
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