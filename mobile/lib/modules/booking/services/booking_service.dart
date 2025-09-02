import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  static BookingService get instance => _instance;

  final String _baseUrl = AppConfig.baseUrl;
  final AuthService _authService = AuthService.instance;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getValidAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  /// Créer une demande de réservation
  Future<Map<String, dynamic>> createBookingRequest({
    required String tripId,
    required String receiverId,
    required String packageDescription,
    required double weightKg,
    required double proposedPrice,
    String? dimensionsCm,
    String? pickupAddress,
    String? deliveryAddress,
    String? specialInstructions,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'trip_id': tripId,
        'receiver_id': receiverId,
        'package_description': packageDescription,
        'weight_kg': weightKg,
        'proposed_price': proposedPrice,
        'dimensions_cm': dimensionsCm,
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'special_instructions': specialInstructions,
      });

      print('Booking request URL: ${_baseUrl}/bookings');
      print('Booking request body: $body');

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings'),
        headers: headers,
        body: body,
      );

      print('Booking response status: ${response.statusCode}');
      print('Booking response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'booking': responseData['booking'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de la création de la réservation',
        };
      }
    } catch (e) {
      print('Erreur BookingService.createBookingRequest: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Récupérer les réservations de l'utilisateur
  Future<Map<String, dynamic>> getUserBookings({String? role}) async {
    try {
      final headers = await _getAuthHeaders();
      
      String url = '${_baseUrl}/bookings';
      if (role != null) {
        url += '?role=$role';
      }

      print('Get bookings URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Get bookings response status: ${response.statusCode}');
      print('Get bookings response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'bookings': responseData['bookings'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de la récupération des réservations',
        };
      }
    } catch (e) {
      print('Erreur BookingService.getUserBookings: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Récupérer une réservation spécifique
  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();

      print('Get booking URL: ${_baseUrl}/bookings/$bookingId');

      final response = await http.get(
        Uri.parse('${_baseUrl}/bookings/$bookingId'),
        headers: headers,
      );

      print('Get booking response status: ${response.statusCode}');
      print('Get booking response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'booking': responseData['booking'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de la récupération de la réservation',
        };
      }
    } catch (e) {
      print('Erreur BookingService.getBooking: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Accepter une réservation (par le propriétaire du voyage)
  Future<Map<String, dynamic>> acceptBooking(String bookingId, {double? finalPrice}) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        if (finalPrice != null) 'final_price': finalPrice,
      });

      print('Accept booking URL: ${_baseUrl}/bookings/$bookingId/accept');

      final response = await http.put(
        Uri.parse('${_baseUrl}/bookings/$bookingId/accept'),
        headers: headers,
        body: body,
      );

      print('Accept booking response status: ${response.statusCode}');
      print('Accept booking response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'booking': responseData['booking'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de l\'acceptation de la réservation',
        };
      }
    } catch (e) {
      print('Erreur BookingService.acceptBooking: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Rejeter une réservation (par le propriétaire du voyage)
  Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();

      print('Reject booking URL: ${_baseUrl}/bookings/$bookingId/reject');

      final response = await http.put(
        Uri.parse('${_baseUrl}/bookings/$bookingId/reject'),
        headers: headers,
      );

      print('Reject booking response status: ${response.statusCode}');
      print('Reject booking response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors du rejet de la réservation',
        };
      }
    } catch (e) {
      print('Erreur BookingService.rejectBooking: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Ajouter une négociation de prix
  Future<Map<String, dynamic>> addNegotiation(String bookingId, double amount, {String? message}) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'amount': amount,
        if (message != null) 'message': message,
      });

      print('Add negotiation URL: ${_baseUrl}/bookings/$bookingId/negotiate');

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/negotiate'),
        headers: headers,
        body: body,
      );

      print('Add negotiation response status: ${response.statusCode}');
      print('Add negotiation response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'negotiation_id': responseData['negotiation_id'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de l\'ajout de la négociation',
        };
      }
    } catch (e) {
      print('Erreur BookingService.addNegotiation: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Marquer une réservation comme prête pour le paiement
  Future<Map<String, dynamic>> markPaymentReady(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();

      print('Mark payment ready URL: ${_baseUrl}/bookings/$bookingId/payment-ready');

      final response = await http.put(
        Uri.parse('${_baseUrl}/bookings/$bookingId/payment-ready'),
        headers: headers,
      );

      print('Mark payment ready response status: ${response.statusCode}');
      print('Mark payment ready response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de la mise à jour du statut',
        };
      }
    } catch (e) {
      print('Erreur BookingService.markPaymentReady: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Ajouter une photo de colis
  Future<Map<String, dynamic>> addPackagePhoto(String bookingId, String photoUrl, {String? cloudinaryId, String? photoType}) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'photo_url': photoUrl,
        if (cloudinaryId != null) 'cloudinary_id': cloudinaryId,
        if (photoType != null) 'photo_type': photoType,
      });

      print('Add package photo URL: ${_baseUrl}/bookings/$bookingId/photos');

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/photos'),
        headers: headers,
        body: body,
      );

      print('Add package photo response status: ${response.statusCode}');
      print('Add package photo response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'photo_id': responseData['photo_id'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de l\'ajout de la photo',
        };
      }
    } catch (e) {
      print('Erreur BookingService.addPackagePhoto: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }
}