import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugStorageCleaner {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Nettoie complètement tous les stockages de l'application
  static Future<void> clearAllStorage() async {
    print('🧹 Début du nettoyage complet du stockage...');
    
    try {
      // 1. Nettoyer FlutterSecureStorage
      await _clearSecureStorage();
      
      // 2. Nettoyer SharedPreferences
      await _clearSharedPreferences();
      
      print('✅ Nettoyage complet terminé avec succès');
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
      rethrow;
    }
  }

  /// Affiche le contenu actuel du stockage sécurisé
  static Future<void> debugSecureStorage() async {
    print('🔍 === DEBUG SECURE STORAGE ===');
    
    try {
      final allKeys = await _secureStorage.readAll();
      
      if (allKeys.isEmpty) {
        print('📭 Stockage sécurisé: VIDE');
      } else {
        print('📝 Clés trouvées: ${allKeys.keys.length}');
        for (final key in allKeys.keys) {
          final value = allKeys[key];
          if (value != null) {
            // Afficher seulement les premiers caractères pour la sécurité
            final preview = value.length > 20 ? '${value.substring(0, 20)}...' : value;
            print('  • $key: "$preview" (longueur: ${value.length})');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la lecture du stockage sécurisé: $e');
    }
    
    print('================================');
  }

  /// Affiche le contenu des SharedPreferences
  static Future<void> debugSharedPreferences() async {
    print('🔍 === DEBUG SHARED PREFERENCES ===');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      if (keys.isEmpty) {
        print('📭 SharedPreferences: VIDE');
      } else {
        print('📝 Clés trouvées: ${keys.length}');
        for (final key in keys) {
          final value = prefs.get(key);
          print('  • $key: $value (type: ${value.runtimeType})');
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la lecture des SharedPreferences: $e');
    }
    
    print('====================================');
  }

  static Future<void> _clearSecureStorage() async {
    print('🗑️ Nettoyage du stockage sécurisé...');
    
    // Lister d'abord ce qui va être supprimé
    final allKeys = await _secureStorage.readAll();
    print('🔑 Clés à supprimer: ${allKeys.keys.toList()}');
    
    // Supprimer toutes les clés une par une
    for (final key in allKeys.keys) {
      await _secureStorage.delete(key: key);
      print('  ✅ Supprimé: $key');
    }
    
    // Vérification finale
    final remainingKeys = await _secureStorage.readAll();
    if (remainingKeys.isEmpty) {
      print('✅ Stockage sécurisé nettoyé avec succès');
    } else {
      print('⚠️ Certaines clés persistent: ${remainingKeys.keys.toList()}');
    }
  }

  static Future<void> _clearSharedPreferences() async {
    print('🗑️ Nettoyage des SharedPreferences...');
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('🔑 Clés à supprimer: ${keys.toList()}');
    
    // Supprimer toutes les données
    await prefs.clear();
    
    // Vérification finale
    final remainingKeys = prefs.getKeys();
    if (remainingKeys.isEmpty) {
      print('✅ SharedPreferences nettoyées avec succès');
    } else {
      print('⚠️ Certaines clés persistent: ${remainingKeys.toList()}');
    }
  }

  /// Crée un widget de debug pour nettoyer le stockage depuis l'interface
  static Widget buildDebugWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            '🛠️ Outils de Debug Storage',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await debugSecureStorage();
              await debugSharedPreferences();
            },
            child: const Text('🔍 Inspecter le stockage'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await clearAllStorage();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('🧹 Nettoyer tout le stockage'),
          ),
        ],
      ),
    );
  }
}