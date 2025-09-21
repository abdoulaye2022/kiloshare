import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modules/auth/services/auth_service.dart';
import '../modules/notifications/services/firebase_notification_service.dart';
import 'auth_token_service.dart';

/// Service centralisé pour gérer la déconnexion complète
/// et vider tous les états persistés dans l'application
class LogoutService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Effectue une déconnexion complète avec nettoyage de tous les états persistés
  static Future<void> performCompleteLogout() async {
    debugPrint('🚪 Début de la déconnexion complète...');
    
    try {
      // 1. Déconnexion via AuthService (appel API + suppression des tokens auth)
      await _performAuthLogout();
      
      // 2. Vider tous les stockages persistants
      await _clearAllPersistedData();
      
      // 3. Nettoyer les services en mémoire
      await _clearInMemoryStates();
      
      // 4. Nettoyer les notifications
      await _clearNotifications();
      
      debugPrint('✅ Déconnexion complète terminée avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de la déconnexion complète: $e');
      // On continue quand même le nettoyage local même si l'API échoue
      await _forceLocalCleanup();
    }
  }

  /// Étape 1: Déconnexion via AuthService
  static Future<void> _performAuthLogout() async {
    debugPrint('🔑 Déconnexion AuthService...');
    try {
      final authService = AuthService.instance;
      await authService.logout(); // Appel API + suppression tokens auth
    } catch (e) {
      debugPrint('⚠️ Erreur AuthService logout: $e (continue quand même)');
    }
  }

  /// Étape 2: Vider tous les stockages persistants
  static Future<void> _clearAllPersistedData() async {
    debugPrint('🗑️ Nettoyage des données persistées...');
    
    await Future.wait([
      _clearSecureStorage(),
      _clearSharedPreferences(),
    ]);
  }

  /// Nettoyer FlutterSecureStorage
  static Future<void> _clearSecureStorage() async {
    debugPrint('🔐 Nettoyage du stockage sécurisé...');
    
    try {
      // Lister toutes les clés avant suppression
      final allKeys = await _secureStorage.readAll();
      debugPrint('📋 Clés à supprimer du stockage sécurisé: ${allKeys.keys.toList()}');
      
      // Supprimer toutes les clés importantes
      await Future.wait([
        // Tokens d'authentification
        _secureStorage.delete(key: 'access_token'),
        _secureStorage.delete(key: 'refresh_token'),
        _secureStorage.delete(key: 'token_expires_at'),
        _secureStorage.delete(key: 'user_data'),
        
        // Token FCM
        _secureStorage.delete(key: 'fcm_token'),
        
        // Autres clés potentielles
        _secureStorage.delete(key: 'search_history'),
        _secureStorage.delete(key: 'user_preferences'),
        _secureStorage.delete(key: 'cached_user_data'),
      ]);
      
      // Nettoyage complet pour être sûr
      await _secureStorage.deleteAll();
      
      debugPrint('✅ Stockage sécurisé nettoyé');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage stockage sécurisé: $e');
    }
  }

  /// Nettoyer SharedPreferences
  static Future<void> _clearSharedPreferences() async {
    debugPrint('📄 Nettoyage des SharedPreferences...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      debugPrint('📋 Clés à supprimer des SharedPreferences: ${keys.toList()}');
      
      // Supprimer des clés spécifiques importantes
      await Future.wait([
        prefs.remove('auth_token'),
        prefs.remove('user_profile'),
        prefs.remove('app_settings'),
        prefs.remove('search_filters'),
        prefs.remove('trip_cache'),
        prefs.remove('notification_settings'),
      ]);
      
      // Nettoyage complet
      await prefs.clear();
      
      debugPrint('✅ SharedPreferences nettoyées');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage SharedPreferences: $e');
    }
  }

  /// Étape 3: Nettoyer les services en mémoire
  static Future<void> _clearInMemoryStates() async {
    debugPrint('🧠 Nettoyage des états en mémoire...');
    
    try {
      // Nettoyer AuthTokenService
      await AuthTokenService.instance.clearToken();
      
      // Réinitialiser d'autres services si nécessaire
      // TODO: Ajouter d'autres services qui ont des états en mémoire
      
      debugPrint('✅ États en mémoire nettoyés');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage états mémoire: $e');
    }
  }

  /// Étape 4: Nettoyer les notifications
  static Future<void> _clearNotifications() async {
    debugPrint('🔔 Nettoyage des notifications...');
    
    try {
      final notificationService = FirebaseNotificationService();
      
      // Vider toutes les notifications locales
      await notificationService.clearAllNotifications();
      
      // Se désabonner de tous les topics (si on les connaît)
      // TODO: Maintenir une liste des topics auxquels l'utilisateur est abonné
      
      debugPrint('✅ Notifications nettoyées');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage notifications: $e');
    }
  }

  /// Nettoyage local forcé en cas d'échec de l'API
  static Future<void> _forceLocalCleanup() async {
    debugPrint('🚨 Nettoyage local forcé...');
    
    try {
      await _clearAllPersistedData();
      await _clearInMemoryStates();
      await _clearNotifications();
      
      debugPrint('✅ Nettoyage local forcé terminé');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage local forcé: $e');
    }
  }

  /// Méthode de debug pour vérifier le nettoyage
  static Future<void> debugVerifyCleanup() async {
    debugPrint('🔍 Vérification du nettoyage...');
    
    try {
      // Vérifier FlutterSecureStorage
      final secureKeys = await _secureStorage.readAll();
      debugPrint('🔐 Clés restantes dans stockage sécurisé: ${secureKeys.keys.toList()}');
      
      // Vérifier SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefKeys = prefs.getKeys();
      debugPrint('📄 Clés restantes dans SharedPreferences: ${prefKeys.toList()}');
      
      // Vérifier AuthTokenService
      final authToken = AuthTokenService.instance.currentToken;
      debugPrint('🔑 Token auth restant: ${authToken != null ? "OUI" : "NON"}');
      
      if (secureKeys.isEmpty && prefKeys.isEmpty && authToken == null) {
        debugPrint('✅ Nettoyage vérifié avec succès');
      } else {
        debugPrint('⚠️ Certaines données persistent encore');
      }
    } catch (e) {
      debugPrint('❌ Erreur vérification nettoyage: $e');
    }
  }
}