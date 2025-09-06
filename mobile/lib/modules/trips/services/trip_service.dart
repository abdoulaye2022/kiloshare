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
      baseUrl: AppConfig.baseUrl,
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
    List<Map<String, dynamic>>? images,
  }) async {
    try {
      // Récupérer le token d'authentification
      final token = await _authService.getValidAccessToken();
      
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      // Générer un titre automatiquement si la description est vide
      final tripTitle = (description != null && description.isNotEmpty) 
          ? description 
          : '$departureCity → $arrivalCity';

      final data = {
        'transport_type': transportType,
        'title': tripTitle, // Champ requis par l'API
        'departure_city': departureCity,
        'departure_country': departureCountry,
        'departure_airport_code': departureAirportCode,
        'departure_date': departureDate.toIso8601String().split('T')[0], // Format YYYY-MM-DD
        'arrival_city': arrivalCity,
        'arrival_country': arrivalCountry,
        'arrival_airport_code': arrivalAirportCode,
        'arrival_date': arrivalDate.toIso8601String().split('T')[0], // Format YYYY-MM-DD
        'available_weight_kg': availableWeightKg, // Corrigé pour correspondre aux règles de validation backend
        'price_per_kg': pricePerKg,
        'currency': currency,
        'flight_number': flightNumber,
        'airline': airline,
        'description': description,
        'special_notes': specialNotes,
        if (restrictedCategories != null) 'restricted_categories': restrictedCategories,
        if (restrictedItems != null) 'restricted_items': restrictedItems,
        if (restrictionNotes != null) 'restriction_notes': restrictionNotes,
        if (images != null) 'images': images,
      };


      final response = await _dio.post(
        '/trips', 
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      
      // Vérifier si response.data est null
      if (response.data == null) {
        throw const TripException('Server response is empty');
      }
      
      if (response.data['success'] == true) {
        // Vérifier la structure de la réponse
        if (response.data['data'] == null || response.data['data']['trip'] == null) {
          throw const TripException('Trip data not found in response');
        }
        
        final trip = Trip.fromJson(response.data['data']['trip']);
        return trip;
      } else {
        throw TripException(response.data['message'] ?? 'Failed to create trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
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

      final response = await _dio.get('/user/trips', 
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
      
      
      if (response.data == null) {
        throw const TripException('Empty response from server');
      }
      
      if (response.data['success'] == true) {
        // Check the correct response structure: data.trips
        if (response.data['data'] == null || response.data['data']['trips'] == null) {
          return <Trip>[];
        }
        
        final tripsData = response.data['data']['trips'] as List<dynamic>;
        
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
    print('🚀 TripService.getTripById: Starting for ID: $id');
    
    try {
      // Try to get token but don't fail if not available (public access)
      String? token;
      try {
        token = await _authService.getValidAccessToken();
        print('🔐 TripService.getTripById: Token obtained: ${token != null ? "✅" : "❌"}');
      } catch (e) {
        print('🔐 TripService.getTripById: No token available: $e');
        // Token not available or expired - continue without auth for public access
      }
      
      // If we have a valid token, try the user-specific endpoint first
      // This allows access to user's own draft trips
      if (token != null && token.isNotEmpty) {
        try {
          print('👤 TripService.getTripById: Trying user-specific endpoint /user/trips/$id');
          
          final userResponse = await _dio.get('/user/trips/$id',
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ),
          );
          
          print('👤 TripService.getTripById: User endpoint response status: ${userResponse.statusCode}');
          print('👤 TripService.getTripById: User endpoint response data type: ${userResponse.data.runtimeType}');
          
          if (userResponse.data['success'] == true && userResponse.data['data']?['trip'] != null) {
            print('👤 TripService.getTripById: User endpoint successful, parsing trip...');
            try {
              final trip = Trip.fromJson(userResponse.data['data']['trip']);
              print('✅ TripService.getTripById: User endpoint trip parsed successfully');
              return trip;
            } catch (parseError) {
              print('❌ TripService.getTripById: User endpoint parse error: $parseError');
              throw parseError;
            }
          }
        } catch (e) {
          // If user endpoint fails, fall back to public endpoint
          print('User trip endpoint failed, trying public: $e');
        }
      }
      
      print('🌍 TripService.getTripById: Trying public endpoint /trips/$id');
      
      // Fall back to public endpoint (for published trips or when not authenticated)
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _dio.get('/trips/$id',
        options: Options(
          headers: headers,
        ),
      );
      
      print('🌍 TripService.getTripById: Public endpoint response status: ${response.statusCode}');
      print('🌍 TripService.getTripById: Public endpoint response data type: ${response.data.runtimeType}');
      print('🌍 TripService.getTripById: Public endpoint response keys: ${response.data is Map ? (response.data as Map).keys.toList() : "NOT A MAP"}');
      
      if (response.data is String) {
        print('❌ TripService.getTripById: ERROR - Response data is a String: ${response.data}');
        throw TripException('Server returned string instead of JSON object');
      }
      
      if (response.data['success'] == true) {
        print('🌍 TripService.getTripById: Public endpoint successful, checking data structure...');
        
        // API returns data in response.data['data']['trip']
        final dataSection = response.data['data'];
        print('🌍 TripService.getTripById: Data section type: ${dataSection.runtimeType}');
        print('🌍 TripService.getTripById: Data section keys: ${dataSection is Map ? (dataSection as Map).keys.toList() : "NOT A MAP"}');
        
        if (dataSection == null) {
          throw TripException('Invalid response format: missing data section');
        }
        
        final tripData = dataSection['trip'];
        print('🌍 TripService.getTripById: Trip data type: ${tripData.runtimeType}');
        print('🌍 TripService.getTripById: Trip data keys: ${tripData is Map ? (tripData as Map).keys.toList() : "NOT A MAP"}');
        
        if (tripData == null) {
          throw TripException('Trip not found');
        }
        
        if (tripData is! Map<String, dynamic>) {
          print('❌ TripService.getTripById: ERROR - Trip data is not a Map<String, dynamic>: ${tripData.runtimeType}');
          print('❌ TripService.getTripById: Trip data content: $tripData');
          throw TripException('Invalid trip data format: expected Map but got ${tripData.runtimeType}');
        }
        
        print('🌍 TripService.getTripById: About to parse trip with Trip.fromJson...');
        try {
          final trip = Trip.fromJson(tripData);
          print('✅ TripService.getTripById: Trip parsed successfully');
          return trip;
        } catch (parseError) {
          print('❌ TripService.getTripById: Parse error: $parseError');
          print('❌ TripService.getTripById: Parse error type: ${parseError.runtimeType}');
          print('❌ TripService.getTripById: Trip data that failed: $tripData');
          throw parseError;
        }
      } else {
        print('❌ TripService.getTripById: API returned success: false');
        throw TripException(response.data['message'] ?? 'Trip not found');
      }
    } on DioException catch (e) {
      print('❌ TripService.getTripById: DioException: $e');
      throw _handleDioException(e);
    } catch (e) {
      print('❌ TripService.getTripById: Generic exception: $e');
      print('❌ TripService.getTripById: Exception type: ${e.runtimeType}');
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
      if (departureDateFrom != null) queryParams['departure_date'] = departureDateFrom;
      if (departureDateTo != null) queryParams['departure_date_to'] = departureDateTo;
      if (minWeight != null) queryParams['min_weight'] = minWeight;
      if (maxPricePerKg != null) queryParams['max_price'] = maxPricePerKg;
      if (currency != null) queryParams['currency'] = currency;
      if (verifiedOnly != null) queryParams['verified_only'] = verifiedOnly;
      if (ticketVerified != null) queryParams['ticket_verified'] = ticketVerified;


      final response = await _dio.get('/search/trips', queryParameters: queryParams);
      
      
      if (response.data['success'] == true) {
        // Check different possible response structures
        dynamic tripsData;
        if (response.data['data'] != null && response.data['data']['trips'] != null) {
          tripsData = response.data['data']['trips'];
        } else if (response.data['trips'] != null) {
          tripsData = response.data['trips'];
        } else {
          throw TripException('No trips data found in response');
        }
        
        final trips = (tripsData as List<dynamic>).map((json) => Trip.fromJson(json)).toList();
        return trips;
      } else {
        throw TripException(response.data['message'] ?? 'Failed to search trips');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      rethrow;
    }
  }

  /// Update trip
  Future<Trip> updateTrip(String tripId, Map<String, dynamic> updates) async {
    try {
      
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.put('/trips/$tripId', 
        data: updates,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      
      // Vérifier si response.data est null
      if (response.data == null) {
        throw const TripException('Server response is empty');
      }
      
      if (response.data['success'] == true) {
        // L'update est réussi, récupérer le voyage complet
        return getTripById(tripId);
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

      final response = await _dio.delete('/trips/$tripId',
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
      
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/publish',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      
      if (response.data == null) {
        throw const TripException('Server returned null response');
      }
      
      if (response.data['success'] == true) {
        final tripData = response.data['trip'];
        
        if (tripData == null) {
          throw const TripException('Trip data is null in successful response');
        }
        
        return Trip.fromJson(tripData);
      } else {
        final message = response.data['message'] ?? 'Failed to publish trip';
        throw TripException(message);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      rethrow;
    }
  }

  /// Pause trip
  Future<Trip> pauseTrip(String tripId, {String? reason}) async {
    try {
      final response = await _dio.post('/trips/$tripId/pause',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
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
      final response = await _dio.post('/trips/$tripId/resume',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
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
      final response = await _dio.post('/trips/$tripId/cancel',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
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
      final response = await _dio.post('/trips/$tripId/complete',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
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
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.get('/user/trips',
        queryParameters: {
          'page': page,
          'limit': limit,
          'status': 'draft',
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
        // Check the correct response structure: data.trips
        if (response.data['data'] == null || response.data['data']['trips'] == null) {
          return <Trip>[];
        }
        
        final draftsData = response.data['data']['trips'] as List<dynamic>;
        final drafts = draftsData.map((json) => Trip.fromJson(json)).toList();
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
        final trip = Trip.fromJson(response.data['trip']);
        return trip;
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
    try {
      
      final response = await _dio.get('/trips',
        queryParameters: {
          'limit': limit,
          // Removed 'status': 'published' as API already filters for published trips
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      
      if (response.data['success'] == true) {
        // API returns data.trips, not just trips
        final dataSection = response.data['data'];
        if (dataSection == null) {
          throw TripException('Invalid response format: missing data section');
        }
        
        final tripsData = dataSection['trips'] as List<dynamic>?;
        if (tripsData == null) {
          throw TripException('Invalid response format: missing trips array');
        }
        
        
        final trips = tripsData.map((json) => Trip.fromJson(json)).toList();
        
        
        return trips;
      } else {
        final errorMessage = response.data['message'] ?? 'Failed to fetch public trips';
        throw TripException(errorMessage);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      rethrow;
    }
  }

  // === NEW STATUS TRANSITION ACTIONS ===

  /// Submit trip for review (draft → pending_review)
  Future<Trip> submitForReview(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/submit-for-review',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        // The API should return updated trip data
        if (response.data['data'] != null && response.data['data']['trip'] != null) {
          return Trip.fromJson(response.data['data']['trip']);
        } else {
          // Fallback: reload the trip
          return getTripById(tripId);
        }
      } else {
        throw TripException(response.data['message'] ?? 'Failed to submit trip for review');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Mark trip as booked (active → booked)
  Future<Trip> markAsBooked(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/mark-as-booked',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to mark trip as booked');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Mark trip as expired (active → expired)
  Future<Trip> markAsExpired(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/mark-as-expired',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to mark trip as expired');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Reactivate paused trip (paused → active)
  Future<Trip> reactivateTrip(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/reactivate',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to reactivate trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Start journey (booked → in_progress)
  Future<Trip> startJourney(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/start-journey',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to start journey');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Complete delivery (in_progress → completed)
  Future<Trip> completeDelivery(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/complete-delivery',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to complete delivery');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Back to draft (rejected → draft)
  Future<Trip> backToDraft(String tripId) async {
    try {
      final response = await _dio.post('/trips/$tripId/back-to-draft',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return getTripById(tripId);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to move trip back to draft');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get available actions for trip based on current status
  Future<List<String>> getAvailableActions(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId/actions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${await _authService.getValidAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true && response.data['data']['actions'] != null) {
        return List<String>.from(response.data['data']['actions']);
      } else {
        throw TripException(response.data['message'] ?? 'Failed to get available actions');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Add Cloudinary images to an existing trip
  Future<void> addCloudinaryImages({
    required String tripId,
    required List<Map<String, dynamic>> images,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.post('/trips/$tripId/cloudinary-images',
        data: {
          'images': images,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] != true) {
        throw TripException(response.data['message'] ?? 'Failed to add images to trip');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
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