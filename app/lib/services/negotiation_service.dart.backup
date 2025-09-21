import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../modules/auth/services/auth_service.dart';

class NegotiationService {
  static final NegotiationService _instance = NegotiationService._internal();
  factory NegotiationService() => _instance;
  NegotiationService._internal();

  static NegotiationService get instance => _instance;

  final String _baseUrl = '${AppConfig.baseUrl}/negotiations';
  final AuthService _authService = AuthService.instance;

  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      print('NegotiationService: No valid token found, unable to make authenticated request');
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Créer une nouvelle négociation
  Future<Map<String, dynamic>> createNegotiation({
    required int tripId,
    required double proposedPrice,
    double? proposedWeight,
    required String packageDescription,
    required String pickupAddress,
    required String deliveryAddress,
    String? specialInstructions,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentication required',
        };
      }
      
      final body = json.encode({
        'trip_id': tripId,
        'proposed_price': proposedPrice,
        'proposed_weight': proposedWeight,
        'package_description': packageDescription,
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'special_instructions': specialInstructions,
      });

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'negotiation': responseData['data']['negotiation'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la création de la négociation',
          'errors': responseData['errors'],
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.createNegotiation: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors de la création de la négociation',
      };
    }
  }

  /// Récupérer mes négociations (en tant qu'expéditeur)
  Future<Map<String, dynamic>> getMyNegotiations() async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentication required',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/my'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'negotiations': responseData['data']['negotiations'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la récupération des négociations',
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.getMyNegotiations: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors de la récupération des négociations',
      };
    }
  }

  /// Récupérer les négociations pour un voyage (en tant que voyageur)
  Future<Map<String, dynamic>> getNegotiationsForTrip(int tripId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/trip/$tripId'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'negotiations': responseData['data']['negotiations'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la récupération des négociations',
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.getNegotiationsForTrip: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors de la récupération des négociations',
      };
    }
  }

  /// Accepter une négociation
  Future<Map<String, dynamic>> acceptNegotiation(int negotiationId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/$negotiationId/accept'),
        headers: headers,
        body: json.encode({}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'negotiation': responseData['data']['negotiation'],
          'booking': responseData['data']['booking'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de l\'acceptation de la négociation',
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.acceptNegotiation: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors de l\'acceptation de la négociation',
      };
    }
  }

  /// Rejeter une négociation
  Future<Map<String, dynamic>> rejectNegotiation(int negotiationId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/$negotiationId/reject'),
        headers: headers,
        body: json.encode({}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors du rejet de la négociation',
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.rejectNegotiation: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors du rejet de la négociation',
      };
    }
  }

  /// Faire une contre-proposition
  Future<Map<String, dynamic>> counterPropose(int negotiationId, double counterPrice, {String? message}) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'counter_price': counterPrice,
        'message': message,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/$negotiationId/counter'),
        headers: headers,
        body: body,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'negotiation': responseData['data']['negotiation'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la contre-proposition',
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.counterPropose: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors de la contre-proposition',
      };
    }
  }

  /// Ajouter un message à une négociation
  Future<Map<String, dynamic>> addMessage(int negotiationId, String message) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'message': message,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/$negotiationId/message'),
        headers: headers,
        body: body,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'negotiation': responseData['data']['negotiation'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de l\'ajout du message',
        };
      }
    } catch (e) {
      print('Erreur NegotiationService.addMessage: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion lors de l\'ajout du message',
      };
    }
  }
}