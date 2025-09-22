import 'package:flutter/material.dart';
import '../modules/auth/services/auth_service.dart';

/// Utilitaire pour gérer l'authentification et les erreurs de session
class AuthHelper {
  static final AuthService _authService = AuthService.instance;

  /// Vérifier si l'utilisateur est authentifié sans déclencher de refresh
  static Future<bool> isAuthenticated() async {
    try {
      return await _authService.hasValidTokens();
    } catch (e) {
      return false;
    }
  }

  /// Obtenir un token valide avec gestion d'erreur robuste
  static Future<String?> getValidToken() async {
    try {
      // Vérifier d'abord si on a des tokens sans déclencher de refresh
      final hasTokens = await _authService.hasValidTokens();
      if (!hasTokens) {
        return null;
      }

      // Ensuite essayer d'obtenir un token valide
      return await _authService.getValidAccessToken();
    } catch (e) {
      debugPrint('AuthHelper: Error getting valid token: $e');
      return null;
    }
  }

  /// Gérer les erreurs d'authentification de manière standardisée
  static void handleAuthError(dynamic error, BuildContext? context) {
    String message = 'Erreur d\'authentification';

    if (error.toString().contains('TripException:')) {
      message = error.toString().replaceFirst('TripException: ', '');
    } else if (error.toString().contains('Authentication token is required')) {
      message = 'Session expirée. Veuillez vous reconnecter.';
    } else if (error.toString().contains('401')) {
      message = 'Session expirée. Veuillez vous reconnecter.';
    }

    debugPrint('AuthHelper: Auth error handled: $message');

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  /// Exécuter une fonction qui nécessite l'authentification
  static Future<T?> executeWithAuth<T>(
    Future<T> Function() operation, {
    BuildContext? context,
    VoidCallback? onAuthFailure,
  }) async {
    try {
      // Vérifier l'authentification
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        if (onAuthFailure != null) {
          onAuthFailure();
        } else if (context != null && context.mounted) {
          handleAuthError('Session expirée', context);
        }
        return null;
      }

      // Exécuter l'opération
      return await operation();
    } catch (e) {
      handleAuthError(e, context);
      return null;
    }
  }

  /// Déconnecter l'utilisateur proprement
  static Future<void> logout({BuildContext? context}) async {
    try {
      await _authService.logout();

      if (context != null) {
        if (context.mounted) {
          // Naviguer vers l'écran de connexion
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('AuthHelper: Error during logout: $e');
    }
  }

  /// Créer des headers d'authentification sécurisés
  static Future<Map<String, String>?> createAuthHeaders() async {
    final token = await getValidToken();
    if (token == null) return null;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Vérifier et rafraîchir la session si nécessaire
  static Future<bool> ensureValidSession() async {
    try {
      final token = await _authService.getValidAccessToken();
      return token != null;
    } catch (e) {
      debugPrint('AuthHelper: Failed to ensure valid session: $e');
      return false;
    }
  }
}