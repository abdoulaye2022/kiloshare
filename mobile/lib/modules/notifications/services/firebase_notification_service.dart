import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../utils/platform_helper.dart';
import 'notification_api_service.dart';

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  final NotificationApiService _notificationApiService = NotificationApiService();

  static BuildContext? _context;
  static String? _currentToken;
  static String? _apnsToken;
  static bool _isBasicInitialized = false;
  static bool _isFullyInitialized = false;
  static String? _lastRegisteredToken;
  static bool _deviceRegistrationInProgress = false;
  static bool _isSimulator = false;

  // Getters
  bool get isInitialized => _isFullyInitialized;
  String? get fcmToken => _currentToken;
  static bool get isSimulator => _isSimulator;

  /// ✅ NOUVELLE MÉTHODE: Initialisation basique au démarrage (sans permissions)
  Future<void> initializeBasic([BuildContext? context]) async {
    if (_isBasicInitialized) return;


    try {
      _context = context;

      // 1. Détecter le simulateur
      await _detectSimulator();

      // 2. Initialiser les notifications locales
      await _configureLocalNotifications();

      // 3. Configurer les handlers de messages
      await _setupMessageHandlers();

      // 4. Récupérer le token en cache s'il existe
      final cachedToken = await _storage.read(key: 'fcm_token');
      if (cachedToken != null && cachedToken.isNotEmpty) {
        _currentToken = cachedToken;
      }

      _isBasicInitialized = true;
    } catch (e, stackTrace) {
    }
  }

  /// ✅ NOUVELLE MÉTHODE: Initialisation complète après connexion
  Future<void> initializeAfterLogin() async {
    if (_isFullyInitialized) {
      return;
    }

    if (!_isBasicInitialized) {
      await initializeBasic();
    }


    try {
      // 1. Demander les permissions
      await requestPermissions();

      // 2. Gérer le token FCM
      await _handlePushNotificationsToken();

      _isFullyInitialized = true;
    } catch (e, stackTrace) {
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
      
      
      bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;

      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      return isAuthorized;
    }
    return false;
  }

  /// ✅ MÉTHODE OPTIMISÉE: Token refresh uniquement lors de la connexion
  Future<void> _handlePushNotificationsToken() async {
    try {

      // Écouter les changements de token SEULEMENT si l'utilisateur est connecté
      _firebaseMessaging.onTokenRefresh.listen((fcmToken) async {
        
        // ✅ PROTECTION ANTI-BOUCLE: Vérifier si le token a vraiment changé
        if (_currentToken == fcmToken) {
          return;
        }
        
        _currentToken = fcmToken;
        await _storage.write(key: 'fcm_token', value: fcmToken);

        if (Platform.isIOS && !_isSimulator && _apnsToken == null) {
          await _tryGetAPNSTokenSafe();
        }

        // ✅ OPTIMISATION: Enregistrer le token SEULEMENT si l'utilisateur est connecté ET si le token a changé
        final authToken = await _storage.read(key: 'access_token');
        final lastRegisteredToken = await _storage.read(key: 'last_registered_token');
        
        if (authToken != null && authToken.isNotEmpty && lastRegisteredToken != fcmToken) {
          await _registerDeviceWithToken();
        } else {
        }
      }).onError((error) {
      });

      await _getInitialTokenSafe();
    } catch (e) {
    }
  }

  Future<void> _getInitialTokenSafe() async {
    try {

      // Traitement spécial iOS pour APNS
      if (Platform.isIOS && !_isSimulator) {
        await _prepareAPNSForIPhone();
      }

      // Attendre un délai puis essayer d'obtenir un nouveau token
      await Future.delayed(Duration(milliseconds: Platform.isAndroid ? 2000 : 8000));

      await _tryGetTokenSafely();
    } catch (e) {
    }
  }

  Future<void> _tryGetTokenSafely() async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {

        final tokenFuture = _firebaseMessaging.getToken();
        final token = await tokenFuture.timeout(
          Duration(seconds: Platform.isAndroid ? 15 : 20),
          onTimeout: () {
            return null;
          },
        );

        if (token != null && token.isNotEmpty) {
          _currentToken = token;
          await _storage.write(key: 'fcm_token', value: token);


          if (Platform.isIOS && !_isSimulator && _apnsToken == null) {
            await _tryGetAPNSTokenSafe();
          }

          // ✅ OPTIMISATION: Enregistrer le token SEULEMENT si l'utilisateur est connecté
          final authToken = await _storage.read(key: 'access_token');
          if (authToken != null && authToken.isNotEmpty) {
            await _registerDeviceWithToken();
          } else {
          }
          return;
        } else {
        }
      } catch (e) {

        if (e.toString().contains('apns-token-not-set')) {
          if (attempt == maxAttempts) {
            break;
          }
        }
      }

      if (attempt < maxAttempts) {
        final delay = Duration(milliseconds: Platform.isAndroid ? 2000 : 3000);
        await Future.delayed(delay);
      }
    }

  }

  Future<void> _prepareAPNSForIPhone() async {
    if (_isSimulator || Platform.isAndroid) return;

    try {
      await Future.delayed(const Duration(milliseconds: 5000));

      final apnsToken = await _firebaseMessaging.getAPNSToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      if (apnsToken != null && apnsToken.isNotEmpty) {
        _apnsToken = apnsToken;
        await _storage.write(key: 'apns_token', value: apnsToken);
      }
    } catch (e) {
    }
  }

  Future<void> _tryGetAPNSTokenSafe() async {
    if (_isSimulator || Platform.isAndroid) return;

    try {
      await Future.delayed(const Duration(milliseconds: 2000));

      final apnsToken = await _firebaseMessaging.getAPNSToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return null;
        },
      );

      if (apnsToken != null && apnsToken.isNotEmpty) {
        _apnsToken = apnsToken;
        await _storage.write(key: 'apns_token', value: apnsToken);

        // ✅ OPTIMISATION: Enregistrer seulement si connecté
        final authToken = await _storage.read(key: 'access_token');
        if (authToken != null && authToken.isNotEmpty) {
          await _registerDeviceWithToken();
        }

      } else {
      }
    } catch (e) {
    }
  }

  /// ✅ NOUVELLE MÉTHODE: Enregistrement du device optimisé avec protection anti-boucle
  Future<void> _registerDeviceWithToken() async {
    if (_deviceRegistrationInProgress) {
      return;
    }

    if (_currentToken == null || _currentToken!.isEmpty) {
      return;
    }

    // ✅ VÉRIFICATION ANTI-BOUCLE: Ne pas re-enregistrer le même token
    final lastRegisteredToken = await _storage.read(key: 'last_registered_token');
    if (lastRegisteredToken == _currentToken) {
      return;
    }

    _deviceRegistrationInProgress = true;

    try {

      final authToken = await _storage.read(key: 'access_token');
      if (authToken == null) {
        return;
      }


      // Envoyer le token au backend KiloShare
      await _sendTokenToBackend(_currentToken!);

      // ✅ MARQUER COMME ENREGISTRÉ pour éviter les duplicatas
      await _storage.write(key: 'last_registered_token', value: _currentToken!);

    } catch (e, stackTrace) {
    } finally {
      _deviceRegistrationInProgress = false;
    }
  }

  /// Envoyer le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      
      final deviceInfo = await _getDeviceInfo();
      
      await _notificationApiService.registerFCMToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
        deviceInfo: deviceInfo,
      );
      
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _setupMessageHandlers() async {
    try {
      // Handler pour les messages en premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        await _showLocalNotification(message);
      });

      // Handler pour l'ouverture de notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        _handleNotificationTap(message.data);
      });

      // Vérifier si l'app a été ouverte via une notification (terminated)
      final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }

    } catch (e) {
    }
  }

  /// Configurer les notifications locales
  Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false, // Ne pas demander maintenant
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNotificationTap(data);
          } catch (e) {
          }
        }
      },
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

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highImportanceChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(normalImportanceChannel);
  }

  /// Afficher une notification locale
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

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode(data),
      );
    }
  }

  /// Gérer le tap sur une notification (navigation)
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (_context == null) return;

    try {

      // Navigation basée sur les données reçues
      // Implémentation de la navigation spécifique à KiloShare
      // (sera implémentée selon vos routes GoRouter)
      
      // TODO: Implementer la navigation selon les types de notifications
      if (data.containsKey('type')) {
        switch (data['type']) {
          case 'booking_request':
            // Naviguer vers les détails de booking
            break;
          case 'trip_update':
            // Naviguer vers les détails de trip  
            break;
          default:
            // Navigation par défaut
            break;
        }
      }
      
    } catch (e) {
    }
  }

  // ✅ MÉTHODES UTILITAIRES

  Future<void> _detectSimulator() async {
    try {
      if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        _isSimulator = !iosInfo.isPhysicalDevice;
      } else {
        _isSimulator = false;
      }
    } catch (e) {
      _isSimulator = false;
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceId = '';
    String osVersion = '';
    String deviceModel = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      osVersion = androidInfo.version.release;
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
      osVersion = iosInfo.systemVersion;
      deviceModel = _isSimulator ? '${iosInfo.model} (Simulator)' : iosInfo.model;
    }

    return {
      'device_id': deviceId,
      'app_version': packageInfo.version,
      'os_version': osVersion,
      'device_model': deviceModel,
    };
  }

  // ✅ MÉTHODES PUBLIQUES

  /// Initialiser après connexion (à appeler dans l'AuthBloc)
  Future<void> registerAfterLogin() async {
    
    if (!_isFullyInitialized) {
      await initializeAfterLogin();
    } else {
    }

    // Forcer l'enregistrement même si déjà initialisé
    await _forceRegisterExistingToken();
  }

  /// ✅ NOUVELLE MÉTHODE: Forcer l'enregistrement d'un token existant SEULEMENT si nécessaire
  Future<void> _forceRegisterExistingToken() async {
    if (_currentToken == null || _currentToken!.isEmpty) {
      // Essayer de récupérer le token du cache
      final cachedToken = await _storage.read(key: 'fcm_token');
      if (cachedToken != null && cachedToken.isNotEmpty) {
        _currentToken = cachedToken;
      } else {
        return;
      }
    }

    // ✅ VÉRIFIER si le token a déjà été enregistré pour éviter la boucle
    final lastRegistered = await _storage.read(key: 'last_registered_token');
    if (lastRegistered == _currentToken) {
      return;
    }

    await _registerDeviceWithToken();
  }

  /// Mettre à jour le contexte
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Nettoyer les données
  Future<void> clearDeviceData() async {
    const keysToRemove = [
      'fcm_token',
      'last_registered_token',
      'apns_token',
    ];

    for (final key in keysToRemove) {
      await _storage.delete(key: key);
    }

    _currentToken = null;
    _apnsToken = null;
    _lastRegisteredToken = null;
    _isBasicInitialized = false;
    _isFullyInitialized = false;
    _deviceRegistrationInProgress = false;

    if (Platform.isAndroid) {
      try {
        await _firebaseMessaging.deleteToken();
      } catch (e) {
      }
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
    await _localNotifications.cancelAll();
  }

  /// Effacer une notification spécifique
  Future<void> clearNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Dispose des ressources
  void dispose() {
    _isBasicInitialized = false;
    _isFullyInitialized = false;
    _deviceRegistrationInProgress = false;
  }
}

/// Handler pour les messages en background (doit être une fonction top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
}