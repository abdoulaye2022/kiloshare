import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/trip_model.dart';

class FavoritesService {
  static FavoritesService? _instance;
  static FavoritesService get instance => _instance ??= FavoritesService._();

  FavoritesService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  Future<Options> _getAuthHeaders() async {
    final token = await AuthService.instance.getValidAccessToken();
    return Options(
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  /// Ajouter un voyage aux favoris
  Future<bool> addToFavorites(String tripId) async {
    try {
      final options = await _getAuthHeaders();
      

      final response = await _dio.post(
        '/favorites/trips/$tripId',
        options: options,
      );


      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Retirer un voyage des favoris
  Future<bool> removeFromFavorites(String tripId) async {
    try {

      final response = await _dio.delete(
        '/favorites/trips/$tripId',
        options: await _getAuthHeaders(),
      );


      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Vérifier si un voyage est en favoris
  Future<bool> isFavorite(String tripId) async {
    try {
      final response = await _dio.get(
        '/favorites/trips/$tripId/status',
        options: await _getAuthHeaders(),
      );


      return response.data['success'] == true &&
          response.data['data']['is_favorite'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Récupérer la liste des voyages favoris
  Future<List<Trip>> getFavoriteTrips() async {
    try {
      final response = await _dio.get(
        '/favorites',
        options: await _getAuthHeaders(),
      );

      if (response.data['success'] == true) {
        final tripsData = response.data['data'] as List;
        return tripsData.map((tripJson) => Trip.fromJson(tripJson)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Basculer l'état favoris d'un voyage
  /// Retourne un Map avec {success: bool, isFavorite: bool}
  Future<Map<String, dynamic>> toggleFavorite(String tripId) async {
    try {

      final response = await _dio.post(
        '/favorites/trips/$tripId/toggle',
        options: await _getAuthHeaders(),
      );


      return {
        'success': response.data['success'] == true,
        'isFavorite': response.data['data']?['data']?['is_favorite'] ?? false,
      };
    } catch (e) {
      return {'success': false, 'isFavorite': false};
    }
  }
}
