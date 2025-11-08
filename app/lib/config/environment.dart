import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des variables d'environnement pour l'application mobile
class Environment {
  // URL de l'API backend
  static String get apiUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8080/api/v1';
  
  // Configuration Google Cloud Storage
  static String get gcsProjectId => dotenv.env['GCS_PROJECT_ID'] ?? '';
  static String get gcsBucketName => dotenv.env['GCS_BUCKET_NAME'] ?? 'kiloshare';
  static String get gcsKeyFile => dotenv.env['GCS_KEY_FILE'] ?? '';

  // URL GCS pour l'accès public
  static String get gcsPublicUrl =>
    'https://storage.googleapis.com/$gcsBucketName';
  
  // Configuration Firebase
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? 'kiloshare-8f7fa';
  static String get firebaseSenderId => dotenv.env['FIREBASE_SENDER_ID'] ?? '450200476606';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  
  // Configuration Stripe
  static String get stripePublishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  
  // Configuration Google Sign-In
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  static String get googleClientSecret => dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';
  
  // Mode debug
  static bool get isDebug => dotenv.env['DEBUG'] == 'true';
  
  /// Initialise la configuration depuis le fichier .env
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    
    // Vérifier les variables critiques
    _validateRequiredVariables();
  }
  
  /// Vérifie que les variables essentielles sont présentes
  static void _validateRequiredVariables() {
    final requiredVars = [
      'CLOUDINARY_CLOUD_NAME',
      'CLOUDINARY_API_KEY', 
      'CLOUDINARY_API_SECRET'
    ];
    
    final missing = <String>[];
    for (final varName in requiredVars) {
      if (dotenv.env[varName]?.isEmpty ?? true) {
        missing.add(varName);
      }
    }
    
    if (missing.isNotEmpty) {
      throw Exception(
        'Variables d\'environnement manquantes: ${missing.join(', ')}\n'
        'Veuillez créer un fichier .env avec ces variables.'
      );
    }
  }
  
  /// Affiche la configuration actuelle (sans les secrets)
  static void printConfig() {
    if (isDebug) {
      debugPrint('=== Configuration Environment ===');
      debugPrint('API URL: $apiUrl');
      debugPrint('GCS Bucket Name: $gcsBucketName');
      debugPrint('GCS Project ID: ${gcsProjectId.isEmpty ? "Non défini" : gcsProjectId}');
      debugPrint('Firebase Project ID: $firebaseProjectId');
      debugPrint('Debug Mode: $isDebug');
      debugPrint('===================================');
    }
  }
}