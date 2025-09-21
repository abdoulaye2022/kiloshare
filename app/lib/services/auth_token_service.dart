import 'package:shared_preferences/shared_preferences.dart';
import '../modules/trips/services/trip_service.dart';

class AuthTokenService {
  static const String _tokenKey = 'auth_token';
  static AuthTokenService? _instance;
  
  AuthTokenService._();
  
  static AuthTokenService get instance {
    _instance ??= AuthTokenService._();
    return _instance!;
  }
  
  String? _currentToken;
  
  // Services that need authentication
  TripService? _tripService;
  
  String? get currentToken => _currentToken;
  
  Future<void> setToken(String token) async {
    _currentToken = token;
    
    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    
    // Update all services
    _updateServices();
  }
  
  Future<void> clearToken() async {
    _currentToken = null;
    
    // Remove from persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _currentToken = prefs.getString(_tokenKey);
    
    if (_currentToken != null) {
      _updateServices();
    }
  }
  
  void _updateServices() {
    if (_currentToken != null) {
      _tripService?.setAuthToken(_currentToken!);
    }
  }
  
  // Service getters with lazy initialization
  TripService get tripService {
    if (_tripService == null) {
      _tripService = TripService();
      if (_currentToken != null) {
        _tripService!.setAuthToken(_currentToken!);
      }
    }
    return _tripService!;
  }
}