import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../config/environment.dart';
import '../modules/auth/services/auth_service.dart';

class NotificationPreferencesService {
  static const String _cacheKey = 'notification_preferences';
  static const Duration _cacheTimeout = Duration(minutes: 30);

  final AuthService _authService;

  NotificationPreferencesService({required AuthService authService}) 
      : _authService = authService;

  /// Récupérer les préférences de notification de l'utilisateur connecté
  Future<Map<String, dynamic>?> getUserPreferences() async {
    try {
      // Essayer d'abord le cache offline
      final cachedPrefs = await _getCachedPreferences();
      if (cachedPrefs != null) {
        return cachedPrefs;
      }

      // Sinon récupérer depuis l'API
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final response = await _authService.dio.get(
        '/notification-preferences',
      );

      final data = response.data;
      if (data['success'] == true) {
        final preferences = data['data']['preferences'];
        
        // Mettre en cache
        await _cachePreferences(preferences);
        
        return preferences;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la récupération des préférences');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _authService.logout();
        throw Exception('Session expirée, veuillez vous reconnecter');
      }
      throw Exception('Erreur réseau: ${e.message}');
    } catch (e) {
      print('Erreur lors de la récupération des préférences: $e');
      
      // En cas d'erreur, essayer de retourner les préférences en cache
      final cachedPrefs = await _getCachedPreferences(ignoreTimeout: true);
      if (cachedPrefs != null) {
        return cachedPrefs;
      }
      
      rethrow;
    }
  }

  /// Mettre à jour les préférences de notification
  Future<Map<String, dynamic>> updateUserPreferences(Map<String, dynamic> updates) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final response = await _authService.dio.put(
        '/notification-preferences',
        data: updates,
      );

      final data = response.data;
      if (data['success'] == true) {
        final preferences = data['data']['preferences'];
        
        // Mettre à jour le cache
        await _cachePreferences(preferences);
        
        return preferences;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la mise à jour');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _authService.logout();
        throw Exception('Session expirée, veuillez vous reconnecter');
      }
      final errorData = e.response?.data;
      throw Exception(errorData?['message'] ?? 'Erreur serveur: ${e.response?.statusCode}');
    } catch (e) {
      print('Erreur lors de la mise à jour des préférences: $e');
      rethrow;
    }
  }

  /// Réinitialiser les préférences aux valeurs par défaut
  Future<Map<String, dynamic>> resetToDefaults() async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final response = await _authService.dio.post(
        '/notification-preferences/reset',
      );

      final data = response.data;
      if (data['success'] == true) {
        final preferences = data['data']['preferences'];
        
        // Mettre à jour le cache
        await _cachePreferences(preferences);
        
        return preferences;
      } else {
        throw Exception(data['message'] ?? 'Erreur lors de la réinitialisation');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _authService.logout();
        throw Exception('Session expirée, veuillez vous reconnecter');
      }
      throw Exception('Erreur serveur: ${e.response?.statusCode}');
    } catch (e) {
      print('Erreur lors de la réinitialisation des préférences: $e');
      rethrow;
    }
  }

  /// Mettre à jour un paramètre général (push, email, sms, etc.)
  Future<Map<String, dynamic>> updateGeneralSetting(String setting, dynamic value) async {
    return await updateUserPreferences({setting: value});
  }

  /// Mettre à jour les heures calmes
  Future<Map<String, dynamic>> updateQuietHours({
    bool? enabled,
    String? startTime,
    String? endTime,
  }) async {
    final updates = <String, dynamic>{};
    
    if (enabled != null) updates['quiet_hours_enabled'] = enabled;
    if (startTime != null) updates['quiet_hours_start'] = startTime;
    if (endTime != null) updates['quiet_hours_end'] = endTime;
    
    return await updateUserPreferences(updates);
  }

  /// Mettre à jour les préférences d'une catégorie de notifications
  Future<Map<String, dynamic>> updateCategoryPreferences(String category, {
    bool? push,
    bool? email,
  }) async {
    final updates = <String, dynamic>{};
    
    if (push != null) updates['${category}_push'] = push;
    if (email != null) updates['${category}_email'] = email;
    
    return await updateUserPreferences(updates);
  }

  /// Vérifier si les notifications peuvent être envoyées maintenant (heures calmes)
  Future<bool> canReceiveNotificationNow() async {
    try {
      final prefs = await getUserPreferences();
      if (prefs == null) return true;

      final quietHours = prefs['quiet_hours'];
      if (quietHours == null || !quietHours['enabled']) return true;

      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final startTime = quietHours['start'];
      final endTime = quietHours['end'];

      // Si les heures calmes traversent minuit (ex: 22:00 à 08:00)
      if (startTime.compareTo(endTime) > 0) {
        return !(currentTime.compareTo(startTime) >= 0 || currentTime.compareTo(endTime) <= 0);
      }
      
      // Heures calmes dans la même journée (ex: 14:00 à 18:00)
      return !(currentTime.compareTo(startTime) >= 0 && currentTime.compareTo(endTime) <= 0);
    } catch (e) {
      print('Erreur lors de la vérification des heures calmes: $e');
      return true; // En cas d'erreur, permettre les notifications
    }
  }

  /// Obtenir les timezones disponibles
  List<String> getAvailableTimezones() {
    return [
      'Europe/Paris',
      'Europe/London',
      'America/New_York',
      'America/Los_Angeles',
      'America/Montreal',
      'America/Toronto',
      'Asia/Tokyo',
      'Australia/Sydney',
      'Africa/Casablanca',
      'Africa/Dakar',
    ];
  }

  /// Obtenir les langues disponibles
  List<Map<String, String>> getAvailableLanguages() {
    return [
      {'code': 'fr', 'name': 'Français'},
      {'code': 'en', 'name': 'English'},
    ];
  }

  /// Obtenir les préférences mises en cache
  Future<Map<String, dynamic>?> _getCachedPreferences({bool ignoreTimeout = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      
      if (cachedData != null) {
        final data = json.decode(cachedData);
        final cacheTime = DateTime.parse(data['cached_at']);
        
        if (ignoreTimeout || DateTime.now().difference(cacheTime) < _cacheTimeout) {
          return data['preferences'];
        }
      }
      
      return null;
    } catch (e) {
      print('Erreur lors de la lecture du cache des préférences: $e');
      return null;
    }
  }

  /// Mettre les préférences en cache
  Future<void> _cachePreferences(Map<String, dynamic> preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'preferences': preferences,
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_cacheKey, json.encode(cacheData));
    } catch (e) {
      print('Erreur lors de la mise en cache des préférences: $e');
    }
  }

  /// Effacer le cache des préférences
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      print('Erreur lors de la suppression du cache des préférences: $e');
    }
  }

  /// Valider un format d'heure (HH:mm:ss)
  bool isValidTimeFormat(String time) {
    final regex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$');
    return regex.hasMatch(time);
  }

  /// Formatter une heure pour l'affichage (HH:mm)
  String formatTimeForDisplay(String time) {
    try {
      if (time.length >= 5) {
        return time.substring(0, 5); // HH:mm
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  /// Convertir une heure d'affichage (HH:mm) en format API (HH:mm:ss)
  String formatTimeForApi(String time) {
    try {
      if (time.length == 5) {
        return '$time:00'; // Ajouter les secondes
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  /// Obtenir les préférences par défaut (pour l'UI)
  Map<String, dynamic> getDefaultPreferences() {
    return {
      'general': {
        'push_enabled': true,
        'email_enabled': true,
        'sms_enabled': true,
        'in_app_enabled': true,
        'marketing_enabled': false,
        'language': 'fr',
        'timezone': 'Europe/Paris',
      },
      'quiet_hours': {
        'enabled': true,
        'start': '22:00:00',
        'end': '08:00:00',
      },
      'categories': {
        'trip_updates': {'push': true, 'email': true},
        'booking_updates': {'push': true, 'email': true},
        'payment_updates': {'push': true, 'email': true},
        'security_alerts': {'push': true, 'email': true},
      },
    };
  }
}