import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';

class DeliveryCodeService {
  static final DeliveryCodeService _instance = DeliveryCodeService._internal();
  factory DeliveryCodeService() => _instance;
  DeliveryCodeService._internal();

  static DeliveryCodeService get instance => _instance;

  final String _baseUrl = AppConfig.baseUrl;
  final AuthService _authService = AuthService.instance;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getValidAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Générer un code de livraison pour une réservation
  Future<Map<String, dynamic>> generateDeliveryCode(String bookingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/generate'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'delivery_code': data['data']['delivery_code'] as Map<String, dynamic>,
          'message': data['message'] ?? 'Code généré'
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Erreur génération'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Erreur: $e'};
    }
  }

  /// Obtenir le code de livraison
  Future<Map<String, dynamic>> getDeliveryCode(String bookingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final deliveryCodeData = data['data']['delivery_code'] as Map<String, dynamic>;
        return {
          'success': true,
          'delivery_code': deliveryCodeData,
        };
      } else {
        return {'success': false, 'error': data['message'] ?? 'Code non trouvé'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Erreur: $e'};
    }
  }

  /// Valider un code de livraison
  Future<Map<String, dynamic>> validateDeliveryCode({
    required String bookingId,
    required String code,
    double? latitude,
    double? longitude,
    List<String>? photoUrls,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'code': code,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photos': photoUrls,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/validate'),
        headers: headers,
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Code validé',
          'data': data['data']
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Code invalide',
          'attempts_remaining': data['data']?['attempts_remaining']
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Erreur: $e'};
    }
  }

  /// Régénérer un code
  Future<Map<String, dynamic>> regenerateDeliveryCode(String bookingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/regenerate'),
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'delivery_code': data['data']['delivery_code'] as Map<String, dynamic>,
          'message': data['message'] ?? 'Code régénéré'
        };
      } else {
        return {'success': false, 'error': data['message'] ?? 'Erreur'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Erreur: $e'};
    }
  }
}
