import 'package:dio/dio.dart';
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/transport_models.dart';

class MultiTransportService {
  final AuthService _authService = AuthService();
  final Dio _dio;

  MultiTransportService({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    return dio;
  }

  Future<List<TransportLimit>> getTransportLimits({String? transportType}) async {
    try {
      final token = await _authService.getValidAccessToken();
      final endpoint = transportType != null 
          ? '/trips/transport-limits/$transportType'
          : '/trips/transport-limits';
      
      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final limitsData = data['data']['limits'] as List;
          return limitsData.map((limit) => TransportLimit.fromJson(limit)).toList();
        }
        throw Exception(data['message'] ?? 'Erreur lors de la récupération des limites');
      }
      
      throw Exception('Erreur réseau: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erreur lors de la récupération des limites de transport: $e');
    }
  }

  Future<MultiTransportPriceSuggestion> getPriceSuggestionMulti({
    required String transportType,
    required String departureCity,
    required String arrivalCity,
    required double weightKg,
    String currency = 'CAD',
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      
      final response = await _dio.post(
        '/trips/price-suggestion-multi',
        data: {
          'transport_type': transportType,
          'departure_city': departureCity,
          'arrival_city': arrivalCity,
          'weight_kg': weightKg,
          'currency': currency,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return MultiTransportPriceSuggestion.fromJson(data['data']['price_suggestion']);
        }
        throw Exception(data['message'] ?? 'Erreur lors du calcul du prix');
      }
      
      if (response.statusCode == 400) {
        final data = response.data;
        throw Exception(data['message'] ?? 'Données invalides');
      }
      
      throw Exception('Erreur réseau: ${response.statusCode}');
    } catch (e) {
      // Check if it's a DioException with 404 status
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw Exception('ENDPOINT_NOT_AVAILABLE');
        }
        throw Exception('Erreur lors du calcul du prix suggéré: ${e.message}');
      }
      
      // If the multi-transport endpoint is not available, throw a specific error
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        throw Exception('ENDPOINT_NOT_AVAILABLE');
      }
      throw Exception('Erreur lors du calcul du prix suggéré: $e');
    }
  }

  Future<List<TransportRecommendation>> getTransportRecommendations({
    required String departureCity,
    required String arrivalCity,
    required double weightKg,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      
      final response = await _dio.post(
        '/trips/transport-recommendations',
        data: {
          'departure_city': departureCity,
          'arrival_city': arrivalCity,
          'weight_kg': weightKg,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final recommendationsData = data['data']['recommendations'] as List;
          return recommendationsData.map((rec) => TransportRecommendation.fromJson(rec)).toList();
        }
        throw Exception(data['message'] ?? 'Erreur lors de la génération des recommandations');
      }
      
      throw Exception('Erreur réseau: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erreur lors de la génération des recommandations: $e');
    }
  }

  Future<Map<String, dynamic>> validateVehicle({
    required String tripId,
    required String make,
    required String model,
    required String licensePlate,
    String? year,
    String? color,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      
      final response = await _dio.post(
        '/trips/$tripId/validate-vehicle',
        data: {
          'make': make,
          'model': model,
          'license_plate': licensePlate,
          if (year != null) 'year': year,
          if (color != null) 'color': color,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'];
        }
        throw Exception(data['message'] ?? 'Erreur lors de la validation du véhicule');
      }
      
      if (response.statusCode == 400) {
        final data = response.data;
        throw Exception(data['message'] ?? 'Données invalides pour la validation');
      }
      
      throw Exception('Erreur réseau: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erreur lors de la validation du véhicule: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listTripsByTransport({
    String? transportType,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      final endpoint = transportType != null 
          ? '/trips/list-by-transport/$transportType'
          : '/trips/list-by-transport/all';
      
      final queryParams = <String, String>{
        if (status != null) 'status': status,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['trips']);
        }
        throw Exception(data['message'] ?? 'Erreur lors de la récupération des voyages');
      }
      
      throw Exception('Erreur réseau: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erreur lors de la récupération des voyages par transport: $e');
    }
  }

  // Helper method to get weight limit for a transport type
  double getWeightLimit(TransportType transportType) {
    switch (transportType) {
      case TransportType.flight:
      case TransportType.plane:
        return 23.0;
      case TransportType.car:
        return 100.0;
    }
  }

  // Helper method to check if transport requires specific information
  bool requiresVehicleInfo(TransportType transportType) {
    return transportType == TransportType.car;
  }

  bool requiresFlightInfo(TransportType transportType) {
    return transportType == TransportType.flight || transportType == TransportType.plane;
  }

  bool supportsFlexibleDeparture(TransportType transportType) {
    return transportType == TransportType.car;
  }

  bool supportsIntermediateStops(TransportType transportType) {
    return transportType == TransportType.car;
  }
}