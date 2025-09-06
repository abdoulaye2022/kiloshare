import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import 'cache_service.dart';

class CacheInitializer {
  static Future<void> initialize() async {
    // Initialiser le service de connectivité
    final connectivity = ConnectivityService();
    connectivity.initialize();

    // Pas besoin d'initialiser CacheService (singleton lazy)
    final cache = CacheService();
    
    // Afficher les stats du cache au démarrage
    final stats = await cache.getCacheStats();
    debugPrint('📱 Cache initialized - Stats: $stats');
  }
}