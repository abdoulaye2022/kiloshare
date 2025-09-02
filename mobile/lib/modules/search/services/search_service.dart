import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/app_config.dart';
import '../models/search_params.dart';
import '../models/search_result.dart';
import '../models/city_suggestion.dart';
import '../models/search_alert.dart';
import '../models/search_history.dart';
import '../models/popular_route.dart';

class SearchService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> _getAuthToken() async {
    return await _storage.read(key: AppConfig.accessTokenKey);
  }

  Map<String, String> _getHeaders([String? token]) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  /// Search for trips with given parameters
  Future<SearchResult> searchTrips(SearchParams params, {int page = 1, int limit = 20}) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        ...params.toQueryParams(),
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/search/trips')
          .replace(queryParameters: queryParams);

      final token = await _getAuthToken();
      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return SearchResult.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la recherche');
        }
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur searchTrips: $e');
      rethrow;
    }
  }

  /// Get city suggestions based on query
  Future<List<CitySuggestion>> getCitySuggestions(String query, {int limit = 10}) async {
    try {
      if (query.trim().length < 2) {
        return [];
      }

      final queryParams = {
        'q': query.trim(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/search/suggestions')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> suggestions = data['data'] ?? [];
          return suggestions.map((json) => CitySuggestion.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la récupération des suggestions');
        }
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getCitySuggestions: $e');
      return [];
    }
  }

  /// Save a search alert
  Future<SearchAlert?> saveSearchAlert(SearchAlert alert) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentification requise');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/search/save-alert'),
        headers: _getHeaders(token),
        body: json.encode(alert.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return SearchAlert.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la sauvegarde de l\'alerte');
        }
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur saveSearchAlert: $e');
      rethrow;
    }
  }

  /// Get user's recent searches
  Future<List<SearchHistory>> getRecentSearches({int limit = 10}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentification requise');
      }

      final queryParams = {
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/search/recent')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> searches = data['data'] ?? [];
          return searches.map((json) => SearchHistory.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la récupération de l\'historique');
        }
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getRecentSearches: $e');
      return [];
    }
  }

  /// Get user's search alerts
  Future<List<SearchAlert>> getUserSearchAlerts({bool activeOnly = true}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentification requise');
      }

      final queryParams = {
        'active_only': activeOnly.toString(),
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/search/alerts')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> alerts = data['data'] ?? [];
          return alerts.map((json) => SearchAlert.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la récupération des alertes');
        }
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getUserSearchAlerts: $e');
      return [];
    }
  }

  /// Delete a search alert
  Future<bool> deleteSearchAlert(int alertId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentification requise');
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/search/alerts/$alertId'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur deleteSearchAlert: $e');
      return false;
    }
  }

  /// Toggle search alert status (active/inactive)
  Future<bool> toggleSearchAlert(int alertId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentification requise');
      }

      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/search/alerts/$alertId/toggle'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur toggleSearchAlert: $e');
      return false;
    }
  }

  /// Get popular routes
  Future<List<PopularRoute>> getPopularRoutes({int limit = 20}) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/search/popular-routes')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> routes = data['data'] ?? [];
          return routes.map((json) => PopularRoute.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la récupération des routes populaires');
        }
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getPopularRoutes: $e');
      return [];
    }
  }
}