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

    debugPrint('🔔 [KILOSHARE] Initialisation basique des notifications...');

    try {
      _context = context;

      // 1. Détecter le simulateur
      await _detectSimulator();
      debugPrint('📱 [KILOSHARE] Device type: ${_isSimulator ? "Simulator" : "Physical"}');

      // 2. Initialiser les notifications locales
      debugPrint('🔔 [KILOSHARE] Initializing local notifications...');
      await _configureLocalNotifications();

      // 3. Configurer les handlers de messages
      debugPrint('📨 [KILOSHARE] Setting up message handlers...');
      await _setupMessageHandlers();

      // 4. Récupérer le token en cache s'il existe
      final cachedToken = await _storage.read(key: 'fcm_token');
      if (cachedToken != null && cachedToken.isNotEmpty) {
        _currentToken = cachedToken;
        debugPrint('📱 [KILOSHARE] Token en cache trouvé: ${cachedToken.substring(0, 20)}...');
      }

      _isBasicInitialized = true;
      debugPrint('✅ [KILOSHARE] Initialisation basique terminée');
    } catch (e, stackTrace) {
      debugPrint('❌ [KILOSHARE] Erreur lors de l\'initialisation basique: $e');
      debugPrint('📍 [KILOSHARE] Stack trace: $stackTrace');
    }
  }

  /// ✅ NOUVELLE MÉTHODE: Initialisation complète après connexion
  Future<void> initializeAfterLogin() async {
    if (_isFullyInitialized) {
      debugPrint('ℹ️ [KILOSHARE] Notifications déjà complètement initialisées - skip');
      return;
    }

    if (!_isBasicInitialized) {
      await initializeBasic();
    }

    debugPrint('🔔 [KILOSHARE] Initialisation complète des notifications après connexion...');

    try {
      // 1. Demander les permissions
      debugPrint('🔒 [KILOSHARE] Requesting permissions...');
      await requestPermissions();

      // 2. Gérer le token FCM
      debugPrint('🔑 [KILOSHARE] Handling FCM token...');
      await _handlePushNotificationsToken();

      _isFullyInitialized = true;
      debugPrint('✅ [KILOSHARE] Initialisation complète terminée!');
    } catch (e, stackTrace) {
      debugPrint('❌ [KILOSHARE] Erreur lors de l\'initialisation complète: $e');
      debugPrint('📍 [KILOSHARE] Stack trace: $stackTrace');
    }
  }

  /// Demander les permissions de notification
  Future<bool> requestPermissions() async {
    debugPrint('🔔 [KILOSHARE] Demande des permissions de notifications...');
    
    if (PlatformHelper.isAndroid) {
      // Permissions Android 13+
      final status = await Permission.notification.request();
      debugPrint('🔔 [KILOSHARE] Permissions Android: ${status.isGranted ? "Accordées" : "Refusées"}');
      return status.isGranted;
    } else if (PlatformHelper.isIOS) {
      // Permissions iOS
      debugPrint('🔔 [KILOSHARE] Demande des permissions iOS...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      
      debugPrint('🔔 [KILOSHARE] Status permission iOS: ${settings.authorizationStatus}');
      debugPrint('🔔 [KILOSHARE] Alert: ${settings.alert}');
      debugPrint('🔔 [KILOSHARE] Badge: ${settings.badge}');
      debugPrint('🔔 [KILOSHARE] Sound: ${settings.sound}');
      
      bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;
      debugPrint('🔔 [KILOSHARE] Permissions iOS: ${isAuthorized ? "Accordées" : "Refusées"}');

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
      debugPrint('🔄 [KILOSHARE] Setting up token refresh listener...');

      // Écouter les changements de token SEULEMENT si l'utilisateur est connecté
      _firebaseMessaging.onTokenRefresh.listen((fcmToken) async {
        debugPrint('🔄 [KILOSHARE] FCM Token refreshed: ${fcmToken.substring(0, 20)}...');
        
        // ✅ PROTECTION ANTI-BOUCLE: Vérifier si le token a vraiment changé
        if (_currentToken == fcmToken) {
          debugPrint('🔄 [KILOSHARE] Token refresh ignored - same token as current');
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
          debugPrint('🔄 [KILOSHARE] New token detected, registering...');
          await _registerDeviceWithToken();
        } else {
          debugPrint('🔄 [KILOSHARE] Token refresh ignored - user not connected or token already registered');
        }
      }).onError((error) {
        debugPrint('❌ [KILOSHARE] Token refresh error: $error');
      });

      await _getInitialTokenSafe();
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error in _handlePushNotificationsToken: $e');
    }
  }

  Future<void> _getInitialTokenSafe() async {
    try {
      debugPrint('🔍 [KILOSHARE] Getting initial FCM token...');

      // Traitement spécial iOS pour APNS
      if (Platform.isIOS && !_isSimulator) {
        debugPrint('🍎 [KILOSHARE] Preparing APNS for iOS...');
        await _prepareAPNSForIPhone();
      }

      // Attendre un délai puis essayer d'obtenir un nouveau token
      debugPrint('⏳ [KILOSHARE] Waiting before token request...');
      await Future.delayed(Duration(milliseconds: Platform.isAndroid ? 2000 : 8000));

      await _tryGetTokenSafely();
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error in _getInitialTokenSafe: $e');
    }
  }

  Future<void> _tryGetTokenSafely() async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('🔄 [KILOSHARE] Attempting to get FCM token (attempt $attempt/$maxAttempts)');

        final tokenFuture = _firebaseMessaging.getToken();
        final token = await tokenFuture.timeout(
          Duration(seconds: Platform.isAndroid ? 15 : 20),
          onTimeout: () {
            debugPrint('⏰ [KILOSHARE] Token request timeout on attempt $attempt');
            return null;
          },
        );

        if (token != null && token.isNotEmpty) {
          _currentToken = token;
          await _storage.write(key: 'fcm_token', value: token);

          debugPrint('✅ [KILOSHARE] FCM token obtained: ${token.substring(0, 20)}...');
          debugPrint('📱 [KILOSHARE] Full token length: ${token.length}');

          if (Platform.isIOS && !_isSimulator && _apnsToken == null) {
            await _tryGetAPNSTokenSafe();
          }

          // ✅ OPTIMISATION: Enregistrer le token SEULEMENT si l'utilisateur est connecté
          final authToken = await _storage.read(key: 'access_token');
          if (authToken != null && authToken.isNotEmpty) {
            await _registerDeviceWithToken();
          } else {
            debugPrint('ℹ️ [KILOSHARE] Utilisateur non connecté, token stocké pour plus tard');
          }
          return;
        } else {
          debugPrint('⚠️ [KILOSHARE] Empty or null token received on attempt $attempt');
        }
      } catch (e) {
        debugPrint('❌ [KILOSHARE] Error getting token (attempt $attempt): $e');

        if (e.toString().contains('apns-token-not-set')) {
          debugPrint('ℹ️ [KILOSHARE] APNS token not set, this is normal for Android');
          if (attempt == maxAttempts) {
            break;
          }
        }
      }

      if (attempt < maxAttempts) {
        final delay = Duration(milliseconds: Platform.isAndroid ? 2000 : 3000);
        debugPrint('⏳ [KILOSHARE] Waiting ${delay.inMilliseconds}ms before retry...');
        await Future.delayed(delay);
      }
    }

    debugPrint('❌ [KILOSHARE] Failed to get FCM token after $maxAttempts attempts');
  }

  Future<void> _prepareAPNSForIPhone() async {
    if (_isSimulator || Platform.isAndroid) return;

    try {
      debugPrint('🍎 [KILOSHARE] Preparing APNS token...');
      await Future.delayed(const Duration(milliseconds: 5000));

      final apnsToken = await _firebaseMessaging.getAPNSToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      if (apnsToken != null && apnsToken.isNotEmpty) {
        _apnsToken = apnsToken;
        await _storage.write(key: 'apns_token', value: apnsToken);
        debugPrint('✅ [KILOSHARE] APNS token obtained: ${apnsToken.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ [KILOSHARE] APNS token is null or empty');
        debugPrint('🔥 ⚠️ CAUSES POSSIBLES:');
        debugPrint('🔥 ⚠️ 1. Test sur simulateur iOS (non supporté)');
        debugPrint('🔥 ⚠️ 2. Configuration APNS manquante dans Firebase Console');
        debugPrint('🔥 ⚠️ 3. Permissions notifications non accordées');
        debugPrint('🔥 ⚠️ 4. Premier lancement - permissions en attente');
        debugPrint('🔥 ⚠️ SOLUTION: Utilisez un appareil iOS réel ou Android');
      }
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error getting APNS token: $e');
    }
  }

  Future<void> _tryGetAPNSTokenSafe() async {
    if (_isSimulator || Platform.isAndroid) return;

    try {
      debugPrint('🍎 [KILOSHARE] Trying to get APNS token safely...');
      await Future.delayed(const Duration(milliseconds: 2000));

      final apnsToken = await _firebaseMessaging.getAPNSToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ [KILOSHARE] APNS token request timeout');
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

        debugPrint('✅ [KILOSHARE] APNS token updated: ${apnsToken.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ [KILOSHARE] APNS token is null or empty');
      }
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error getting APNS token safely: $e');
    }
  }

  /// ✅ NOUVELLE MÉTHODE: Enregistrement du device optimisé avec protection anti-boucle
  Future<void> _registerDeviceWithToken() async {
    if (_deviceRegistrationInProgress) {
      debugPrint('⏳ [KILOSHARE] Device registration already in progress');
      return;
    }

    if (_currentToken == null || _currentToken!.isEmpty) {
      debugPrint('⚠️ [KILOSHARE] No FCM token available for registration');
      return;
    }

    // ✅ VÉRIFICATION ANTI-BOUCLE: Ne pas re-enregistrer le même token
    final lastRegisteredToken = await _storage.read(key: 'last_registered_token');
    if (lastRegisteredToken == _currentToken) {
      debugPrint('🔄 [KILOSHARE] Token already registered, skipping duplicate registration');
      return;
    }

    _deviceRegistrationInProgress = true;

    try {
      debugPrint('🔄 [KILOSHARE] Starting device registration...');

      final authToken = await _storage.read(key: 'access_token');
      if (authToken == null) {
        debugPrint('⚠️ [KILOSHARE] No auth token, skipping device registration');
        return;
      }

      debugPrint('🔄 [KILOSHARE] Registering device with FCM token: ${_currentToken!.substring(0, 20)}...');

      // Envoyer le token au backend KiloShare
      await _sendTokenToBackend(_currentToken!);

      // ✅ MARQUER COMME ENREGISTRÉ pour éviter les duplicatas
      await _storage.write(key: 'last_registered_token', value: _currentToken!);

      debugPrint('✅ [KILOSHARE] Device registered successfully!');
    } catch (e, stackTrace) {
      debugPrint('❌ [KILOSHARE] Device registration failed: $e');
      debugPrint('📍 [KILOSHARE] Stack trace: $stackTrace');
    } finally {
      _deviceRegistrationInProgress = false;
    }
  }

  /// Envoyer le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      debugPrint('🔥 [KILOSHARE] Envoi du token FCM au backend: ${token.substring(0, 20)}...');
      
      final deviceInfo = await _getDeviceInfo();
      
      await _notificationApiService.registerFCMToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
        deviceInfo: deviceInfo,
      );
      
      debugPrint('🔥 [KILOSHARE] Token FCM envoyé avec succès au backend');
    } catch (e) {
      debugPrint('🔥 [KILOSHARE] Erreur lors de l\'envoi du token FCM: $e');
      rethrow;
    }
  }

  Future<void> _setupMessageHandlers() async {
    try {
      // Handler pour les messages en premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('📨 [KILOSHARE] Foreground message received: ${message.notification?.title}');
        debugPrint('📨 [KILOSHARE] Message data: ${message.data}');
        await _showLocalNotification(message);
      });

      // Handler pour l'ouverture de notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        debugPrint('👆 [KILOSHARE] Notification opened app: ${message.notification?.title}');
        _handleNotificationTap(message.data);
      });

      // Vérifier si l'app a été ouverte via une notification (terminated)
      final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }

      debugPrint('✅ [KILOSHARE] Message handlers configured');
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error setting up message handlers: $e');
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
            debugPrint('❌ [KILOSHARE] Error parsing notification payload: $e');
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
      debugPrint('👆 [KILOSHARE] Handling notification tap: $data');

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
      debugPrint('❌ [KILOSHARE] Error handling notification tap: $e');
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
    debugPrint('🔄 [KILOSHARE] registerAfterLogin called - fully initialized: $_isFullyInitialized');
    
    if (!_isFullyInitialized) {
      await initializeAfterLogin();
    } else {
      debugPrint('ℹ️ [KILOSHARE] Already fully initialized, skipping init');
    }

    // Forcer l'enregistrement même si déjà initialisé
    await _forceRegisterExistingToken();
  }

  /// ✅ NOUVELLE MÉTHODE: Forcer l'enregistrement d'un token existant SEULEMENT si nécessaire
  Future<void> _forceRegisterExistingToken() async {
    if (_currentToken == null || _currentToken!.isEmpty) {
      debugPrint('⚠️ [KILOSHARE] No FCM token available for registration after login');
      // Essayer de récupérer le token du cache
      final cachedToken = await _storage.read(key: 'fcm_token');
      if (cachedToken != null && cachedToken.isNotEmpty) {
        _currentToken = cachedToken;
        debugPrint('🔍 [KILOSHARE] Token récupéré du cache: ${cachedToken.substring(0, 20)}...');
      } else {
        debugPrint('❌ [KILOSHARE] Aucun token FCM disponible');
        return;
      }
    }

    // ✅ VÉRIFIER si le token a déjà été enregistré pour éviter la boucle
    final lastRegistered = await _storage.read(key: 'last_registered_token');
    if (lastRegistered == _currentToken) {
      debugPrint('✅ [KILOSHARE] Token déjà enregistré, pas besoin de re-enregistrer');
      return;
    }

    debugPrint('🔄 [KILOSHARE] Forçage de l\'enregistrement du token FCM...');
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
        debugPrint('❌ [KILOSHARE] Error deleting FCM token: $e');
      }
    }
  }

  /// Marquer une notification comme lue
  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      await _notificationApiService.markAsRead(notificationId);
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error marking notification as read: $e');
    }
  }

  /// Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    try {
      return await _notificationApiService.getUnreadCount();
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error getting unread count: $e');
      return 0;
    }
  }

  /// S'abonner à un topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ [KILOSHARE] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error subscribing to topic: $e');
    }
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ [KILOSHARE] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ [KILOSHARE] Error unsubscribing from topic: $e');
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
  debugPrint('📨 [KILOSHARE] Background message: ${message.notification?.title}');
}