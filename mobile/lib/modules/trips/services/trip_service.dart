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
      print('TripService: Response data is null: ${response.data == null}');
      print('TripService: Response data type: ${response.data?.runtimeType}');
      
      // Vérifier si response.data est null
      if (response.data == null) {
        print('TripService: ERROR - response.data is null');
        throw const TripException('Server response is empty');
      }
      
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
        } else if (trip.status == TripStatus.active) {
          print('TripService: Trip published immediately');
        } else if (trip.status == TripStatus.pendingReview) {
          print('TripService: Trip flagged for review');
        }
        
        return trip;
      } else {
        print('TripService: Trip creation failed: ${response.data['message']}');
        throw TripException(response.data['message'] ?? 'Failed to create trip');
      }
    } on DioException catch (e) {
      print('TripService: DioException caught: $e');
      print('TripService: DioException type: ${e.type}');
      print('TripService: DioException message: ${e.message}');
      print('TripService: DioException response: ${e.response}');
      print('TripService: DioException response data: ${e.response?.data}');
      print('TripService: DioException response status: ${e.response?.statusCode}');
      throw _handleDioException(e);
    } catch (e) {
      print('TripService: General exception caught: $e');
      print('TripService: Exception type: ${e.runtimeType}');
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

      print('TripService: Making request to /trips/list...');
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
      
      print('TripService: Response status: ${response.statusCode}');
      print('TripService: Response data: ${response.data}');
      print('TripService: Response data type: ${response.data.runtimeType}');
      
      if (response.data == null) {
        throw const TripException('Empty response from server');
      }
      
      if (response.data['success'] == true) {
        if (response.data['trips'] == null) {
          print('TripService: No trips data in response');
          return <Trip>[];
        }
        
        final tripsData = response.data['trips'] as List<dynamic>;
        print('TripService: Found ${tripsData.length} trips in response');
        
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
      print('=== TRIP SERVICE GET BY ID DEBUG START ===');
      print('TripService: getTripById called with ID: "$id"');
      print('TripService: ID type: ${id.runtimeType}');
      print('TripService: ID length: ${id.length}');
      
      // Try to get token but don't fail if not available (public access)
      String? token;
      try {
        token = await _authService.getValidAccessToken();
        print('TripService: Auth token retrieved successfully');
        if (token != null) {
          print('TripService: Token length: ${token.length}');
          print('TripService: Token preview: ${token.length > 20 ? token.substring(0, 20) : token}...');
        }
      } catch (e) {
        // Token not available or expired - continue without auth for public access
        print('TripService: No auth token available for getTripById - Error: $e');
        print('TripService: Continuing with public access');
      }
      
      // Prepare headers - include auth if available, but don't require it
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        print('TripService: Using authenticated request for getTripById');
      } else {
        print('TripService: Using public request for getTripById');
      }

      print('TripService: Request headers: ${headers.keys.toList()}');
      print('TripService: Making GET request to: ${_dio.options.baseUrl}/trips/$id');

      final response = await _dio.get('/trips/$id',
        options: Options(
          headers: headers,
        ),
      );
      
      print('TripService: Response received');
      print('TripService: - Status Code: ${response.statusCode}');
      print('TripService: - Response Headers: ${response.headers.map}');
      print('TripService: - Response Data Type: ${response.data.runtimeType}');
      print('TripService: - Response Success Field: ${response.data?['success']}');
      print('TripService: - Response Message Field: ${response.data?['message']}');
      print('TripService: - Response Trip Field Present: ${response.data?['trip'] != null}');
      
      if (response.data is Map) {
        print('TripService: Full response data keys: ${response.data.keys.toList()}');
      }
      print('=== TRIP SERVICE API RESPONSE DEBUG ===');
      
      if (response.data['success'] == true) {
        print('TripService: Response indicates success, parsing trip data...');
        final tripData = response.data['trip'];
        print('TripService: Trip data type: ${tripData.runtimeType}');
        if (tripData is Map) {
          print('TripService: Trip data keys: ${tripData.keys.toList()}');
          print('TripService: Trip ID from response: ${tripData['id']}');
          print('TripService: Trip status from response: ${tripData['status']}');
          print('TripService: Trip user_id from response: ${tripData['user_id']}');
        }
        
        final trip = Trip.fromJson(response.data['trip']);
        print('TripService: Trip parsed successfully');
        print('TripService: - Parsed Trip ID: ${trip.id}');
        print('TripService: - Parsed Trip Status: ${trip.status}');
        print('TripService: - Parsed Trip User ID: ${trip.userId}');
        print('=== TRIP SERVICE GET BY ID DEBUG SUCCESS ===');
        return trip;
      } else {
        print('TripService: Response indicates failure');
        print('TripService: - Error message: ${response.data['message']}');
        print('=== TRIP SERVICE GET BY ID DEBUG FAILURE ===');
        throw TripException(response.data['message'] ?? 'Trip not found');
      }
    } on DioException catch (e) {
      print('=== TRIP SERVICE GET BY ID DIO EXCEPTION ===');
      print('TripService: DioException caught in getTripById');
      print('TripService: - Exception Type: ${e.type}');
      print('TripService: - Exception Message: ${e.message}');
      print('TripService: - Response Status Code: ${e.response?.statusCode}');
      print('TripService: - Response Data: ${e.response?.data}');
      print('=== TRIP SERVICE DIO EXCEPTION END ===');
      throw _handleDioException(e);
    } catch (e) {
      print('=== TRIP SERVICE GET BY ID GENERAL EXCEPTION ===');
      print('TripService: General exception caught in getTripById');
      print('TripService: - Exception Type: ${e.runtimeType}');
      print('TripService: - Exception Message: $e');
      print('=== TRIP SERVICE GENERAL EXCEPTION END ===');
      rethrow;
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
      print('TripService: Updating trip $tripId');
      print('TripService: Updates data: ${updates}');
      print('TripService: Updates keys: ${updates.keys.toList()}');
      
      // Debug restriction fields specifically
      if (updates.containsKey('restricted_categories')) {
        print('TripService: restricted_categories = ${updates['restricted_categories']} (${updates['restricted_categories'].runtimeType})');
      }
      if (updates.containsKey('restricted_items')) {
        print('TripService: restricted_items = ${updates['restricted_items']} (${updates['restricted_items'].runtimeType})');
      }
      if (updates.containsKey('restriction_notes')) {
        print('TripService: restriction_notes = ${updates['restriction_notes']}');
      }
      
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      print('TripService: Making PUT request to /trips/$tripId/update');
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
      
      print('TripService: Update response status: ${response.statusCode}');
      print('TripService: Update response data: ${response.data}');
      
      // Vérifier si response.data est null
      if (response.data == null) {
        print('TripService: ERROR - response.data is null in updateTrip');
        throw const TripException('Server response is empty');
      }
      
      if (response.data['success'] == true) {
        // La structure de réponse est: {success: true, trip: {...}}
        // Pas {success: true, data: {trip: {...}}}
        return Trip.fromJson(response.data['trip']);
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
        // Price suggestion is directly in response.data, not in data.price_suggestion
        final priceSuggestionData = response.data['price_suggestion'];
        if (priceSuggestionData == null) {
          throw TripException('Price suggestion field is missing from response data');
        }
        return PriceSuggestion.fromJson(priceSuggestionData);
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
        // Breakdown is directly in response.data, not in data.breakdown
        final breakdownData = response.data['breakdown'];
        if (breakdownData == null) {
          throw TripException('Price breakdown field is missing from response data');
        }
        return PriceBreakdown.fromJson(breakdownData);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to get price breakdown');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Publish trip (draft to active)
  Future<Trip> publishTrip(String tripId) async {
    try {
      print('TripService: Publishing trip with ID: $tripId');
      
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      print('TripService: Making POST request to /trips/$tripId/publish');
      final response = await _dio.post('/trips/$tripId/publish',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('TripService: Publish response received');
      print('TripService: - Status Code: ${response.statusCode}');
      print('TripService: - Response Data Type: ${response.data.runtimeType}');
      print('TripService: - Response Data: ${response.data}');
      
      if (response.data == null) {
        throw const TripException('Server returned null response');
      }
      
      if (response.data['success'] == true) {
        print('TripService: Success field is true, parsing trip data');
        final tripData = response.data['trip'];
        
        if (tripData == null) {
          throw const TripException('Trip data is null in successful response');
        }
        
        print('TripService: Trip data type: ${tripData.runtimeType}');
        return Trip.fromJson(tripData);
      } else {
        final message = response.data['message'] ?? 'Failed to publish trip';
        print('TripService: Publish failed with message: $message');
        throw TripException(message);
      }
    } on DioException catch (e) {
      print('TripService: DioException in publishTrip: ${e.message}');
      throw _handleDioException(e);
    } catch (e) {
      print('TripService: Unexpected error in publishTrip: $e');
      rethrow;
    }
  }

  /// Pause trip
  Future<Trip> pauseTrip(String tripId, {String? reason}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final data = <String, dynamic>{};
      if (reason != null) data['reason'] = reason;

      final response = await _dio.post('/trips/$tripId/pause',
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
        return Trip.fromJson(response.data['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to pause trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Resume trip
  Future<Trip> resumeTrip(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/resume',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to resume trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Cancel trip
  Future<Trip> cancelTrip(String tripId, {String? reason, String? details}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final data = <String, dynamic>{};
      if (reason != null) data['reason'] = reason;
      if (details != null) data['details'] = details;

      final response = await _dio.post('/trips/$tripId/cancel',
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
        return Trip.fromJson(response.data['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to cancel trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Complete trip
  Future<Trip> completeTrip(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/complete',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to complete trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Add trip to favorites
  Future<void> addToFavorites(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/favorite',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] != true) {
        throw TripException(response.data['message'] ?? 'Failed to add trip to favorites');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Remove trip from favorites
  Future<void> removeFromFavorites(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.delete('/trips/$tripId/favorite',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] != true) {
        throw TripException(response.data['message'] ?? 'Failed to remove trip from favorites');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Report trip
  Future<void> reportTrip(String tripId, {
    required String reportType,
    String? description,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final data = {
        'report_type': reportType,
        if (description != null) 'description': description,
      };

      final response = await _dio.post('/trips/$tripId/report',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] != true) {
        throw TripException(response.data['message'] ?? 'Failed to report trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get user's drafts
  Future<List<Trip>> getDrafts({int page = 1, int limit = 20}) async {
    try {
      print('TripService: getDrafts() called - fetching user drafts...');
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }
      print('TripService: Making request to /trips/drafts...');

      final response = await _dio.get('/trips/drafts',
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
      
      print('TripService: getDrafts response status: ${response.statusCode}');
      if (response.data['success'] == true) {
        if (response.data['trips'] == null) {
          print('TripService: No drafts found in response');
          return <Trip>[];
        }
        
        final draftsData = response.data['trips'] as List<dynamic>;
        print('TripService: Found ${draftsData.length} drafts in response');
        final drafts = draftsData.map((json) => Trip.fromJson(json)).toList();
        print('TripService: Parsed ${drafts.length} draft objects successfully');
        return drafts;
      } else {
        throw TripException(response.data['message'] ?? 'Failed to fetch drafts');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get user's favorites
  Future<List<Trip>> getFavorites({int page = 1, int limit = 20}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.get('/trips/favorites',
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
        if (response.data['trips'] == null) {
          return <Trip>[];
        }
        
        final tripsData = response.data['trips'] as List<dynamic>;
        return tripsData.map((json) => Trip.fromJson(json)).toList();
      } else {
        throw TripException(response.data['message'] ?? 'Failed to fetch favorites');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get trip analytics
  Future<Map<String, dynamic>> getTripAnalytics(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.get('/trips/$tripId/analytics',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return response.data['analytics'];
      } else {
        throw TripException(response.data['message'] ?? 'Failed to fetch trip analytics');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Share trip
  Future<String> shareTrip(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/share',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return response.data['share_url'];
      } else {
        throw TripException(response.data['message'] ?? 'Failed to share trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Duplicate trip
  Future<Trip> duplicateTrip(String tripId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/duplicate',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['trip']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to duplicate trip');
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

  /// Get public trips (approved and published)
  Future<List<Trip>> getPublicTrips({int limit = 10}) async {
    print('=== DEBUG: getPublicTrips START ===');
    print('DEBUG: Requesting public trips with limit: $limit');
    print('DEBUG: No authentication token will be used for public trips');
    try {
      print('DEBUG: Making GET request to /trips/public');
      final response = await _dio.get('/trips/public',
        queryParameters: {
          'limit': limit,
          'status': 'published',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      print('DEBUG: Response received - Status: ${response.statusCode}');
      print('DEBUG: Response data type: ${response.data?.runtimeType}');
      
      if (response.data['success'] == true) {
        print('DEBUG: Success response received');
        final tripsData = response.data['trips'] as List<dynamic>;
        print('DEBUG: Found ${tripsData.length} trips in response');
        final trips = tripsData.map((json) => Trip.fromJson(json)).toList();
        print('DEBUG: Successfully parsed ${trips.length} Trip objects');
        print('=== DEBUG: getPublicTrips END - SUCCESS ===');
        return trips;
      } else {
        print('DEBUG: Error response - success: false');
        print('DEBUG: Error message: ${response.data['message']}');
        throw TripException(response.data['message'] ?? 'Failed to fetch public trips');
      }
    } on DioException catch (e) {
      print('=== DEBUG: DioException in getPublicTrips ===');
      print('DEBUG: DioException type: ${e.type}');
      print('DEBUG: DioException message: ${e.message}');
      print('DEBUG: DioException response: ${e.response?.data}');
      print('DEBUG: DioException status: ${e.response?.statusCode}');
      throw _handleDioException(e);
    } catch (e) {
      print('=== DEBUG: General Exception in getPublicTrips ===');
      print('DEBUG: Exception type: ${e.runtimeType}');
      print('DEBUG: Exception message: $e');
      rethrow;
    }
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