import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../models/booking_model.dart';
import '../../../utils/auth_helper.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  static BookingService get instance => _instance;

  final String _baseUrl = AppConfig.baseUrl;

  Future<Map<String, String>?> _getAuthHeaders() async {
    try {
      // Utiliser l'AuthHelper pour une gestion plus robuste
      final headers = await AuthHelper.createAuthHeaders();
      if (headers == null) {
        throw Exception('Authentication token is required. Please log in again.');
      }
      return headers;
    } catch (e) {
      print('BookingService: Authentication error: $e');
      throw Exception('Authentication token is required. Please log in again.');
    }
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
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

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


      // Vérifier si la réponse est du JSON valide
      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        print('Erreur décodage JSON response: ${response.body}');
        return {
          'success': false,
          'error': 'Réponse serveur invalide (status: ${response.statusCode})',
        };
      }

      if (response.statusCode == 201) {
        return {
          'success': true,
          'booking': responseData['data']?['booking'],
          'payment': responseData['data']?['payment'], // Inclure les infos de paiement
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la création de la réservation (${response.statusCode})',
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
  Future<Map<String, dynamic>> getUserBookings({String? role, bool includeArchived = false}) async {
    try {
      final headers = await _getAuthHeaders();

      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      String url = '$_baseUrl/bookings';
      List<String> queryParams = [];

      if (role != null) {
        queryParams.add('role=$role');
      }

      if (includeArchived) {
        queryParams.add('include_archived=true');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
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
  Future<Map<String, dynamic>> acceptBooking(String bookingId, {double? totalPrice}) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        if (totalPrice != null) 'total_price': totalPrice,
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
  Future<Map<String, dynamic>> rejectBooking(String bookingId, {String? reason}) async {
    try {
      final headers = await _getAuthHeaders();

      final body = reason != null ? json.encode({'reason': reason}) : null;

      final response = await http.put(
        Uri.parse('${_baseUrl}/bookings/$bookingId/reject'),
        headers: headers,
        body: body,
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

  /// Annuler une réservation (par l'expéditeur)
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/cancel'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Réservation annulée avec succès',
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Erreur lors de l\'annulation de la réservation',
        };
      }
    } catch (e) {
      print('Erreur BookingService.cancelBooking: $e');
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

  /// Obtenir les détails de paiement (client_secret, etc.)
  Future<Map<String, dynamic>> getPaymentDetails(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

      final response = await http.get(
        Uri.parse('${_baseUrl}/bookings/$bookingId/payment/details'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'client_secret': responseData['data']['client_secret'],
          'payment_intent_id': responseData['data']['payment_intent_id'],
          'amount': responseData['data']['amount'],
          'currency': responseData['data']['currency'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la récupération des détails de paiement',
        };
      }
    } catch (e) {
      print('Erreur BookingService.getPaymentDetails: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// OBSOLÈTE: Confirmer le paiement (nouveau système de capture différée)
  /// Cette méthode n'est plus utilisée. Le paiement est maintenant effectué IMMÉDIATEMENT
  /// après la création de la réservation via Stripe SDK, plus besoin de confirmation manuelle.
  @Deprecated('Payment confirmation has been replaced by immediate payment after booking creation')
  /*
  Future<Map<String, dynamic>> confirmPayment(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/payment/confirm'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'booking': responseData['data']['booking'] ?? responseData['booking'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la confirmation du paiement',
        };
      }
    } catch (e) {
      print('Erreur BookingService.confirmPayment: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }
  */

  /// Capturer le paiement manuellement (transporteur)
  @Deprecated('Manual payment capture has been replaced by automatic capture upon delivery code validation')
  Future<Map<String, dynamic>> capturePayment(String bookingId) async {
    // DÉSACTIVÉ: La capture manuelle a été remplacée par la capture automatique
    // lors de la validation du code secret de livraison
    return {
      'success': false,
      'error': 'La capture manuelle des paiements a été désactivée.',
      'message': 'Le paiement sera automatiquement capturé lors de la validation du code secret de livraison.',
      'disabled_feature': true,
    };
  }

  /// Obtenir le statut du paiement
  Future<Map<String, dynamic>> getPaymentStatus(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

      final response = await http.get(
        Uri.parse('${_baseUrl}/bookings/$bookingId/payment/status'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'payment_status': responseData['data']['payment_status'],
          'booking_status': responseData['data']['booking_status'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la récupération du statut',
        };
      }
    } catch (e) {
      print('Erreur BookingService.getPaymentStatus: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Archiver une réservation
  Future<Map<String, dynamic>> archiveBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/archive'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Réservation archivée avec succès',
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de l\'archivage',
        };
      }
    } catch (e) {
      print('Erreur BookingService.archiveBooking: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Désarchiver une réservation
  Future<Map<String, dynamic>> unarchiveBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

      final response = await http.post(
        Uri.parse('${_baseUrl}/bookings/$bookingId/unarchive'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Réservation désarchivée avec succès',
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la désarchivage',
        };
      }
    } catch (e) {
      print('Erreur BookingService.unarchiveBooking: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Réessayer le paiement d'une réservation
  Future<Map<String, dynamic>> retryPayment(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Authentification requise. Veuillez vous reconnecter.',
        };
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/payment/retry'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          ...responseData['data'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la réessai du paiement',
        };
      }
    } catch (e) {
      print('Erreur BookingService.retryPayment: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }
}