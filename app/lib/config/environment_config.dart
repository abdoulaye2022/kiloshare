import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  development,
  production,
}

class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.development;

  /// Initialiser la configuration d'environnement
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");

    final envString = dotenv.env['ENVIRONMENT']?.toLowerCase();
    switch (envString) {
      case 'production':
        _currentEnvironment = Environment.production;
        break;
      case 'development':
      default:
        _currentEnvironment = Environment.development;
        break;
    }
  }

  /// Obtenir l'environnement actuel
  static Environment get currentEnvironment => _currentEnvironment;

  /// Vérifier si on est en développement
  static bool get isDevelopment => _currentEnvironment == Environment.development;

  /// Vérifier si on est en production
  static bool get isProduction => _currentEnvironment == Environment.production;

  /// Obtenir l'URL de l'API selon l'environnement
  static String get apiUrl {
    switch (_currentEnvironment) {
      case Environment.production:
        return dotenv.env['API_URL_PROD'] ?? 'https://m2atodev.com/api.kiloshare/public';
      case Environment.development:
        return dotenv.env['API_URL_DEV'] ?? 'http://127.0.0.1:8080/api/v1';
    }
  }

  /// Obtenir l'URL de la plateforme web selon l'environnement
  static String get webUrl {
    switch (_currentEnvironment) {
      case Environment.production:
        return dotenv.env['WEB_URL_PROD'] ?? 'https://kiloshare.com';
      case Environment.development:
        return dotenv.env['WEB_URL_DEV'] ?? 'http://localhost:3000';
    }
  }

  /// Obtenir la configuration Cloudinary
  static String get cloudinaryCloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryApiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get cloudinaryApiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  static String get cloudinaryUploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  /// Obtenir la configuration Firebase
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseSenderId => dotenv.env['FIREBASE_SENDER_ID'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';

  /// Obtenir la configuration Stripe
  static String get stripePublishableKey {
    switch (_currentEnvironment) {
      case Environment.production:
        return dotenv.env['STRIPE_PUBLISHABLE_KEY_PROD'] ?? dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      case Environment.development:
        return dotenv.env['STRIPE_PUBLISHABLE_KEY_DEV'] ?? dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    }
  }

  /// Obtenir la configuration Google Sign-In
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  static String get googleClientSecret => dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';

  /// Mode debug
  static bool get isDebugMode {
    final debugString = dotenv.env['DEBUG']?.toLowerCase();
    return debugString == 'true' && isDevelopment;
  }

  /// Obtenir toutes les informations d'environnement pour le debug
  static Map<String, dynamic> get environmentInfo => {
    'environment': _currentEnvironment.name,
    'isDevelopment': isDevelopment,
    'isProduction': isProduction,
    'apiUrl': apiUrl,
    'webUrl': webUrl,
    'isDebugMode': isDebugMode,
  };

  /// Méthode pour changer l'environnement programmatiquement (pour les tests)
  static void setEnvironment(Environment environment) {
    _currentEnvironment = environment;
  }

  /// Affiche la configuration actuelle (sans les secrets) pour le debug
  static void printConfig() {
    if (isDebugMode) {
      debugPrint('=== Configuration Environment ===');
      debugPrint('Environment: ${_currentEnvironment.name}');
      debugPrint('Is Development: $isDevelopment');
      debugPrint('Is Production: $isProduction');
      debugPrint('API URL: $apiUrl');
      debugPrint('Web URL: $webUrl');
      debugPrint('Cloudinary Cloud Name: $cloudinaryCloudName');
      debugPrint('Cloudinary API Key: ${cloudinaryApiKey.isEmpty ? "Non défini" : "${cloudinaryApiKey.substring(0, 6)}..."}');
      debugPrint('Cloudinary Upload Preset: $cloudinaryUploadPreset');
      debugPrint('Firebase Project ID: $firebaseProjectId');
      debugPrint('Debug Mode: $isDebugMode');
      debugPrint('===================================');
    }
  }
}