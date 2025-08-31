import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../config/app_config.dart';
import '../models/trip_model.dart';
import '../../../data/locations_data.dart';
import '../../auth/services/auth_service.dart';

class TripService {
  final Dio _dio;
  final AuthService _authService;
  
  TripService({Dio? dio, AuthService? authService}) 
    : _dio = dio ?? _createDio(),
      _authService = authService ?? AuthService.instance;

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.baseUrl}/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Note: Intercepteur désactivé temporairement, gestion manuelle des headers
    // dio.interceptors.add(AuthInterceptor(AuthService()));
    
    return dio;
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Create a new trip
  Future<Trip> createTrip({
    required String transportType,
    required String departureCity,
    required String departureCountry,
    String? departureAirportCode,
    required DateTime departureDate,
    required String arrivalCity,
    required String arrivalCountry,
    String? arrivalAirportCode,
    required DateTime arrivalDate,
    required double availableWeightKg,
    required double pricePerKg,
    String currency = 'CAD',
    String? flightNumber,
    String? airline,
    String? description,
    String? specialNotes,
    List<String>? restrictedCategories,
    List<String>? restrictedItems,
    String? restrictionNotes,
  }) async {
    try {
      // Récupérer le token d'authentification
      final token = await _authService.getValidAccessToken();
      
      print('TripService: Attempting trip creation');
      print('TripService: Token available: ${token != null}');
      if (token != null) {
        print('TripService: Token length: ${token.length}');
        print('TripService: Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      }
      
      if (token == null || token.isEmpty) {
        print('TripService: No valid token available');
        throw const TripException('Authentication token is required. Please log in again.');
      }

      print('TripService: Token validation successful, preparing API call...');

      final data = {
        'transport_type': transportType,
        'departure_city': departureCity,
        'departure_country': departureCountry,
        'departure_airport_code': departureAirportCode,
        'departure_date': departureDate.toIso8601String(),
        'arrival_city': arrivalCity,
        'arrival_country': arrivalCountry,
        'arrival_airport_code': arrivalAirportCode,
        'arrival_date': arrivalDate.toIso8601String(),
        'available_weight_kg': availableWeightKg,
        'price_per_kg': pricePerKg,
        'currency': currency,
        'flight_number': flightNumber,
        'airline': airline,
        'description': description,
        'special_notes': specialNotes,
        if (restrictedCategories != null) 'restricted_categories': restrictedCategories,
        if (restrictedItems != null) 'restricted_items': restrictedItems,
        if (restrictionNotes != null) 'restriction_notes': restrictionNotes,
      };

      print('TripService: Request data prepared: ${data.keys.toList()}');
      print('TripService: Making API call to /trips/create...');

      final response = await _dio.post(
        '/trips/create', 
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('TripService: API call completed');
      print('TripService: Response status: ${response.statusCode}');
      print('TripService: Response data: ${response.data}');
      
      if (response.data['success'] == true) {
        print('TripService: Trip created successfully');
        
        // Vérifier la structure de la réponse
        if (response.data['trip'] == null) {
          print('TripService: Warning - trip field is null in response');
          print('TripService: Full response: ${response.data}');
          throw const TripException('Trip data not found in response');
        }
        
        print('TripService: Parsing trip data...');
        final trip = Trip.fromJson(response.data['trip']);
        
        // Vérifier si le voyage a été publié ou est en attente d'approbation
        print('TripService: Trip status: ${trip.status.value}');
        if (trip.status == TripStatus.pendingApproval) {
          print('TripService: Trip submitted for approval');
        } else if (trip.status == TripStatus.published) {
          print('TripService: Trip published immediately');
        } else if (trip.status == TripStatus.flaggedForReview) {
          print('TripService: Trip flagged for review');
        }
        
        return trip;
      } else {
        print('TripService: Trip creation failed: ${response.data['message']}');
        throw TripException(response.data['message'] ?? 'Failed to create trip');
      }
    } on DioException catch (e) {
      print('TripService: DioException caught: $e');
      throw _handleDioException(e);
    } catch (e) {
      print('TripService: General exception caught: $e');
      throw TripException('Failed to create trip: $e');
    }
  }

  /// Get user's trips
  Future<List<Trip>> getUserTrips({int page = 1, int limit = 20}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.get('/trips/list', 
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        final List<dynamic> tripsData = response.data['data']['trips'];
        return tripsData.map((json) => Trip.fromJson(json)).toList();
      } else {
        throw TripException(response.data['message'] ?? 'Failed to fetch trips');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get trip by ID
  Future<Trip> getTripById(String id) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.get('/trips/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['data']['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Trip not found');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Search trips
  Future<List<Trip>> searchTrips({
    String? departureCity,
    String? arrivalCity,
    String? departureCountry,
    String? arrivalCountry,
    String? departureDateFrom,
    String? departureDateTo,
    double? minWeight,
    double? maxPricePerKg,
    String? currency,
    bool? verifiedOnly,
    bool? ticketVerified,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      
      if (departureCity != null) queryParams['departure_city'] = departureCity;
      if (arrivalCity != null) queryParams['arrival_city'] = arrivalCity;
      if (departureCountry != null) queryParams['departure_country'] = departureCountry;
      if (arrivalCountry != null) queryParams['arrival_country'] = arrivalCountry;
      if (departureDateFrom != null) queryParams['departure_date_from'] = departureDateFrom;
      if (departureDateTo != null) queryParams['departure_date_to'] = departureDateTo;
      if (minWeight != null) queryParams['min_weight'] = minWeight;
      if (maxPricePerKg != null) queryParams['max_price_per_kg'] = maxPricePerKg;
      if (currency != null) queryParams['currency'] = currency;
      if (verifiedOnly != null) queryParams['verified_only'] = verifiedOnly;
      if (ticketVerified != null) queryParams['ticket_verified'] = ticketVerified;

      final response = await _dio.get('/trips/search', queryParameters: queryParams);
      
      if (response.data['success'] == true) {
        final List<dynamic> tripsData = response.data['data']['trips'];
        return tripsData.map((json) => Trip.fromJson(json)).toList();
      } else {
        throw TripException(response.data['message'] ?? 'Failed to search trips');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Update trip
  Future<Trip> updateTrip(String tripId, Map<String, dynamic> updates) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.put('/trips/$tripId/update', 
        data: updates,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['data']['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to update trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Delete trip
  Future<void> deleteTrip(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.delete('/trips/$tripId/delete',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] != true) {
        throw TripException(response.data['message'] ?? 'Failed to delete trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Validate ticket
  Future<Trip> validateTicket(String tripId, {
    String? flightNumber,
    String? airline,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final data = <String, dynamic>{};
      if (flightNumber != null) data['flight_number'] = flightNumber;
      if (airline != null) data['airline'] = airline;

      final response = await _dio.post('/trips/$tripId/validate-ticket', 
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['data']['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to validate ticket');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get price suggestion
  Future<PriceSuggestion> getPriceSuggestion({
    required String departureCity,
    required String departureCountry,
    required String arrivalCity,
    required String arrivalCountry,
    String currency = 'CAD',
  }) async {
    try {
      final response = await _dio.get('/trips/price-suggestion', queryParameters: {
        'departure_city': departureCity,
        'departure_country': departureCountry,
        'arrival_city': arrivalCity,
        'arrival_country': arrivalCountry,
        'currency': currency,
      });
      
      if (response.data['success'] == true) {
        return PriceSuggestion.fromJson(response.data['data']['price_suggestion']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to get price suggestion');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get price breakdown
  Future<PriceBreakdown> getPriceBreakdown({
    required double pricePerKg,
    required double weightKg,
    String currency = 'CAD',
  }) async {
    try {
      final response = await _dio.get('/trips/price-breakdown', queryParameters: {
        'price_per_kg': pricePerKg,
        'weight_kg': weightKg,
        'currency': currency,
      });
      
      if (response.data['success'] == true) {
        return PriceBreakdown.fromJson(response.data['data']['breakdown']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to get price breakdown');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  TripException _handleDioException(DioException e) {
    if (e.response != null && e.response!.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return TripException(data['message']);
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return TripException('Connection timeout. Please check your internet connection.');
      case DioExceptionType.connectionError:
        return TripException('Unable to connect to server. Please check your internet connection.');
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 401) {
          return TripException('Authentication required. Please log in again.');
        } else if (e.response?.statusCode == 403) {
          return TripException('Access denied.');
        } else if (e.response?.statusCode == 404) {
          return TripException('Resource not found.');
        }
        return TripException('Server error occurred.');
      default:
        return TripException('Network error occurred. Please try again.');
    }
  }

  /// Get cities for autocomplete using LocationsData
  List<Map<String, dynamic>> getCities() {
    return LocationsData.getAllCitiesForAutocomplete();
  }

  /// Get countries for selection
  List<Map<String, String>> getCountries() {
    return LocationsData.countries;
  }
}

class TripException implements Exception {
  final String message;
  const TripException(this.message);

  @override
  String toString() => 'TripException: $message';
}


// Restricted items data
class RestrictedItemsData {
  static const List<String> categories = [
    'Liquides et gels',
    'Produits dangereux',
    'Objets tranchants',
    'Électronique',
    'Alimentation',
    'Médicaments',
    'Documents et argent',
    'Objets de valeur',
  ];

  static const Map<String, List<String>> itemsByCategory = {
    'Liquides et gels': [
      'Parfums et cosmétiques liquides',
      'Produits d\'hygiène liquides',
      'Boissons alcoolisées',
      'Produits chimiques',
    ],
    'Produits dangereux': [
      'Batteries lithium',
      'Produits inflammables',
      'Gaz comprimés',
      'Produits corrosifs',
    ],
    'Objets tranchants': [
      'Couteaux et lames',
      'Ciseaux',
      'Outils tranchants',
    ],
    'Électronique': [
      'Appareils avec batteries non amovibles',
      'Équipements électroniques fragiles',
      'Téléphones et ordinateurs',
    ],
    'Alimentation': [
      'Produits périssables',
      'Viande et produits laitiers',
      'Fruits et légumes frais',
    ],
    'Médicaments': [
      'Médicaments sur ordonnance',
      'Substances contrôlées',
      'Seringues et aiguilles',
    ],
    'Documents et argent': [
      'Documents officiels',
      'Espèces importantes',
      'Cartes bancaires',
    ],
    'Objets de valeur': [
      'Bijoux coûteux',
      'Œuvres d\'art',
      'Objets de collection',
    ],
  };

  static List<String> getAllItems() {
    return itemsByCategory.values.expand((items) => items).toList();
  }
}