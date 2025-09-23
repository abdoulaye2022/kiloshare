import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'environment_config.dart';

class AppConfig {
  static const String appName = 'KiloShare';
  static const String appVersion = '1.0.0';

  // API Configuration
  static String get baseUrl {
    // Utiliser la nouvelle configuration d'environnement
    return EnvironmentConfig.apiUrl;
  }
  
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String isFirstLaunchKey = 'is_first_launch';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const double defaultElevation = 4.0;
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxMessageLength = 1000;
  static const double maxFileSize = 10 * 1024 * 1024; // 10MB
  
  // Map Configuration
  static const double defaultLatitude = 48.8566;
  static const double defaultLongitude = 2.3522;
  static const double defaultZoom = 12.0;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Features
  static const bool enableBiometrics = true;
  static const bool enableNotifications = true;
  static const bool enableLocationServices = true;
  
  // Environment
  static bool get isDevelopment => EnvironmentConfig.isDevelopment;
  static bool get isProduction => EnvironmentConfig.isProduction;
}