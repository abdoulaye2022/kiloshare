import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  DateTime? _lastSyncTime;
  Timer? _connectionCheckTimer;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  DateTime? get lastSyncTime => _lastSyncTime;

  String get offlineMessage {
    if (_lastSyncTime == null) return "Mode hors-ligne";
    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);
    
    if (difference.inMinutes < 60) {
      return "Mode hors-ligne - Données d'il y a ${difference.inMinutes}min";
    } else if (difference.inHours < 24) {
      return "Mode hors-ligne - Données d'il y a ${difference.inHours}h";
    } else {
      return "Mode hors-ligne - Données du ${_lastSyncTime!.day}/${_lastSyncTime!.month}";
    }
  }

  void initialize() {
    _checkConnectivity();
    _startPeriodicCheck();
  }

  Future<void> _checkConnectivity() async {
    bool wasOnline = _isOnline;
    
    try {
      final result = await InternetAddress.lookup('google.com');
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (_isOnline && !wasOnline) {
        // Vient de se reconnecter
        _updateLastSyncTime();
      }
    } catch (_) {
      _isOnline = false;
    }

    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  void _startPeriodicCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 10), 
      (_) => _checkConnectivity()
    );
  }

  void _updateLastSyncTime() {
    _lastSyncTime = DateTime.now();
  }

  void markSyncSuccessful() {
    if (_isOnline) {
      _updateLastSyncTime();
      notifyListeners();
    }
  }

  Future<bool> testConnection() async {
    await _checkConnectivity();
    return _isOnline;
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }
}