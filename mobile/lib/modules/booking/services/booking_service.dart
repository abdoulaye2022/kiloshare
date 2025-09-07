import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/booking_model.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  static BookingService get instance => _instance;

  final String _baseUrl = AppConfig.baseUrl;
  final AuthService _authService = AuthService.instance;

  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      print('BookingService: No valid token found, unable to make authenticated request');
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Créer une demande de réservation
  Future<Map<String, dynamic>> createBookingRequest({
    required String tripId,
    required String packageDescription,
    required double weight,
    String? dimensionsCm,
    String? pickupAddress,
    String? deliveryAddress,
    String? pickupNotes,
    String? deliveryNotes,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'trip_id': int.parse(tripId),
        'package_description': packageDescription,
        'weight': weight,
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'pickup_notes': pickupNotes,
        'delivery_notes': deliveryNotes,
      });


      final response = await http.post(
        Uri.parse('$_baseUrl/bookings'),
        headers: headers,
        body: body,
      );


      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'booking': responseData['data']['booking'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la création de la réservation',
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

  /// Récupérer les réservations envoyées par l'utilisateur
  Future<List<BookingModel>> getSentBookings() async {
    try {
      final result = await getUserBookings(role: 'sender');
      if (result['success']) {
        final bookingsData = result['bookings'] as List;
        return bookingsData.map((data) => BookingModel.fromJson(data)).toList();
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      print('Erreur BookingService.getSentBookings: $e');
      rethrow;
    }
  }

  /// Récupérer les réservations reçues par l'utilisateur
  Future<List<BookingModel>> getReceivedBookings() async {
    try {
      final result = await getUserBookings(role: 'receiver');
      if (result['success']) {
        final bookingsData = result['bookings'] as List;
        return bookingsData.map((data) => BookingModel.fromJson(data)).toList();
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      print('Erreur BookingService.getReceivedBookings: $e');
      rethrow;
    }
  }

  /// Récupérer les réservations de l'utilisateur
  Future<Map<String, dynamic>> getUserBookings({String? role}) async {
    try {
      final headers = await _getAuthHeaders();
      
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }
      
      String url = '$_baseUrl/bookings';
      if (role != null) {
        url += '?role=$role';
      }


      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );


      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'bookings': responseData['data']['bookings'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la récupération des réservations',
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


      final response = await http.get(
        Uri.parse('${_baseUrl}/bookings/$bookingId'),
        headers: headers,
      );


      final responseData = json.decode(response.body);
      print('BookingService.getBooking response: $responseData');

      if (response.statusCode == 200) {
        // Handle both direct booking response and nested data.booking response
        dynamic bookingData;
        if (responseData['booking'] != null) {
          bookingData = responseData['booking'];
        } else if (responseData['data'] != null && responseData['data']['booking'] != null) {
          bookingData = responseData['data']['booking'];
        }
        
        if (bookingData != null) {
          return {
            'success': true,
            'booking': bookingData,
          };
        } else {
          return {
            'success': false,
            'error': 'Données de réservation manquantes dans la réponse',
          };
        }
      } else {
        return {
          'success': false,
          'error': responseData?['error'] ?? responseData?['message'] ?? 'Erreur lors de la récupération de la réservation',
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


      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/accept'),
        headers: headers,
        body: body,
      );


      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'booking': responseData['data']['booking'] ?? responseData['booking'],
          'message': responseData['message'],
        };
      } else {
        // Handle specific Stripe Connect errors
        String errorMessage = responseData?['message'] ?? 'Erreur lors de l\'acceptation de la réservation';
        Map<String, dynamic> errorData = responseData?['errors'] ?? {};
        
        // Check if it's a Stripe-related error that should redirect to wallet
        if (errorData['error_code'] == 'stripe_account_required' || 
            errorData['error_code'] == 'stripe_account_incomplete') {
          return {
            'success': false,
            'error': errorMessage,
            'stripe_required': true,
            'redirect_url': errorData['redirect_url'],
            'onboarding_url': errorData['onboarding_url'],
            'action': errorData['action'],
          };
        }
        
        return {
          'success': false,
          'error': errorMessage,
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


      final response = await http.put(
        Uri.parse('${_baseUrl}/bookings/$bookingId/reject'),
        headers: headers,
      );


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


      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/negotiate'),
        headers: headers,
        body: body,
      );


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


      final response = await http.put(
        Uri.parse('${_baseUrl}/bookings/$bookingId/payment-ready'),
        headers: headers,
      );


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


      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/photos'),
        headers: headers,
        body: body,
      );


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