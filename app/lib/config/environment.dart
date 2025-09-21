import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des variables d'environnement pour l'application mobile
class Environment {
  // URL de l'API backend
  static String get apiUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000/api/v1';
  
  // Configuration Cloudinary
  static String get cloudinaryCloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryApiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get cloudinaryApiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  static String get cloudinaryUploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'kiloshare_uploads';
  
  // URL Cloudinary construite dynamiquement
  static String get cloudinaryUploadUrl => 
    'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';
  
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
      debugPrint('Cloudinary Cloud Name: $cloudinaryCloudName');
      debugPrint('Cloudinary API Key: ${cloudinaryApiKey.isEmpty ? "Non défini" : "${cloudinaryApiKey.substring(0, 6)}..."}');
      debugPrint('Cloudinary Upload Preset: $cloudinaryUploadPreset');
      debugPrint('Firebase Project ID: $firebaseProjectId');
      debugPrint('Debug Mode: $isDebug');
      debugPrint('===================================');
    }
  }
}