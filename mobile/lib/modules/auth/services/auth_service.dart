import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'simple_social_auth_service.dart';
import '../../../config/app_config.dart';

class AuthService {
  static AuthService? _instance;
  
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final Dio _dio;
  late final SimpleSocialAuthService _socialAuthService;
  
  Dio get dio => _dio;

  AuthService._internal({Dio? dio}) : _dio = dio ?? _createDio() {
    _socialAuthService = SimpleSocialAuthService(_dio);
    _setupAuthInterceptor();
  }
  
  void _setupAuthInterceptor() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        // Add access token to requests if available
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException err, ErrorInterceptorHandler handler) async {
        // Check if this is a 401 error (Unauthorized)
        if (err.response?.statusCode == 401) {
          print('AuthService: Received 401, attempting token refresh...');
          
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken == null) {
            print('AuthService: No refresh token, clearing tokens');
            await clearTokens();
            handler.next(err);
            return;
          }

          try {
            // Attempt to refresh the token
            await refreshTokens('');
            print('AuthService: Token refresh successful, retrying request');
            
            // Retry the original request with the new token
            final newToken = await _storage.read(key: 'access_token');
            final requestOptions = err.requestOptions;
            requestOptions.headers['Authorization'] = 'Bearer $newToken';
            
            final response = await _dio.fetch(requestOptions);
            handler.resolve(response);
            
          } catch (refreshError) {
            print('AuthService: Token refresh failed: $refreshError');
            await clearTokens();
            handler.next(err);
          }
        } else {
          handler.next(err);
        }
      },
    ));
  }

  factory AuthService({Dio? dio}) {
    return _instance ??= AuthService._internal(dio: dio);
  }

  static AuthService get instance => _instance ??= AuthService._internal();

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

    // Add logging interceptor in debug mode
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print(obj),
    ));
    
    // Add custom interceptor for debugging format exception
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        print('=== Raw Response Debug ===');
        print('Status: ${response.statusCode}');
        print('Data type: ${response.data.runtimeType}');
        print('Raw data: ${response.data}');
        if (response.data is String) {
          final dataStr = response.data as String;
          print('String length: ${dataStr.length}');
          if (dataStr.isNotEmpty) {
            print('First char code: ${dataStr.codeUnitAt(0)}');
            print('First 10 chars: "${dataStr.substring(0, dataStr.length > 10 ? 10 : dataStr.length)}"');
          }
        }
        print('========================');
        handler.next(response);
      },
      onError: (error, handler) {
        print('=== Interceptor Error Debug ===');
        print('Error type: ${error.runtimeType}');
        print('Message: ${error.message}');
        print('Response: ${error.response}');
        print('==============================');
        handler.next(error);
      },
    ));

    return dio;
  }

  // Token management
  Future<void> _saveTokens(AuthTokens tokens) async {
    print('AuthService: _saveTokens() called');
    print('AuthService: Access token length: ${tokens.accessToken.length}');
    print('AuthService: Refresh token present: ${tokens.refreshToken != null}');
    print('AuthService: Token expiry: ${tokens.expiryDate}');
    
    try {
      await Future.wait([
        _storage.write(key: 'access_token', value: tokens.accessToken),
        if (tokens.refreshToken != null)
          _storage.write(key: 'refresh_token', value: tokens.refreshToken!),
        _storage.write(key: 'token_expires_at', value: tokens.expiryDate.toIso8601String()),
      ]);
      print('AuthService: Tokens saved successfully');
      
      // Vérification immédiate
      final savedToken = await _storage.read(key: 'access_token');
      print('AuthService: Verification - saved token length: ${savedToken?.length ?? 0}');
    } catch (e) {
      print('AuthService: Error saving tokens: $e');
      rethrow;
    }
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    print('AuthService: getAccessToken() - Token found: ${token != null}');
    if (token != null) {
      print('AuthService: Token length: ${token.length}');
      print('AuthService: Token starts with: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    }
    return token;
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<String?> getStoredToken() async {
    return await getAccessToken();
  }

  bool isTokenExpired(String token) {
    try {
      // Decode JWT payload (basic validation without signature verification)
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if necessary for base64 decoding
      final normalizedPayload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      
      final decoded = utf8.decode(base64Decode(normalizedPayload));
      final Map<String, dynamic> claims = jsonDecode(decoded);
      
      // Check expiration time
      final exp = claims['exp'];
      if (exp == null) return true;
      
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      // If token parsing fails, consider it expired
      return true;
    }
  }

  Future<bool> isTokenExpiredStored() async {
    final expiryStr = await _storage.read(key: 'token_expires_at');
    if (expiryStr == null) return true;
    
    final expiry = DateTime.parse(expiryStr);
    return DateTime.now().isAfter(expiry);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
      _storage.delete(key: 'token_expires_at'),
      _storage.delete(key: 'user_data'),
    ]);
  }

  // User data management
  Future<void> _saveUser(User user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
  }

  Future<void> saveUser(User user) async {
    await _saveUser(user);
  }

  Future<User?> getCurrentUser() async {
    final userData = await _storage.read(key: 'user_data');
    if (userData == null) return null;
    
    try {
      return User.fromJson(jsonDecode(userData));
    } catch (e) {
      return null;
    }
  }

  // Auth API calls
  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      // Test de validation de l'email avant envoi
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(request.email.trim())) {
        throw AuthException('Email format invalid: ${request.email}');
      }
      
      final requestData = request.toJson();
      print('=== Final API Request Debug ===');
      print('Register Request Data: $requestData');
      print('Register Request Email: "${request.email}"');
      print('Email validation passed: ${emailRegex.hasMatch(request.email)}');
      print('JSON keys: ${requestData.keys.toList()}');
      print('JSON values: ${requestData.values.toList()}');
      print('==============================');
      
      final response = await _dio.post(
        '/auth/register', 
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          responseType: ResponseType.plain, // Force plain text response
        ),
      );
      
      // Manual JSON parsing with better error handling
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.data as String);
      } catch (e) {
        print('=== JSON Parsing Error ===');
        print('Error: $e');
        print('Raw response: "${response.data}"');
        print('Response length: ${response.data?.toString().length ?? 0}');
        print('=========================');
        throw FormatException('Invalid JSON response from server');
      }
      
      // Debug response content
      print('=== Response Debug ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Raw Response Type: ${response.data.runtimeType}');
      print('Raw Response Content: ${response.data}');
      print('=====================');
      
      final apiResponse = ApiResponse.fromJson(
        responseData,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (!apiResponse.success || apiResponse.data == null) {
        throw AuthException(apiResponse.message);
      }

      final authResponse = apiResponse.data!;
      await _saveTokens(authResponse.tokens);
      await _saveUser(authResponse.user);

      return authResponse;
    } on DioException catch (e) {
      print('=== DioException Debug ===');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Response: ${e.response}');
      if (e.response != null) {
        print('Status Code: ${e.response!.statusCode}');
        print('Response Data: ${e.response!.data}');
      }
      print('========================');
      throw _handleDioException(e);
    } on FormatException catch (e) {
      print('=== FormatException Debug ===');
      print('Message: ${e.message}');
      print('Source: ${e.source}');
      print('Offset: ${e.offset}');
      print('=============================');
      throw AuthException('Invalid server response format: ${e.message}');
    } catch (e) {
      print('=== Unknown Exception Debug ===');
      print('Type: ${e.runtimeType}');
      print('Message: $e');
      print('===============================');
      throw AuthException('Registration failed: $e');
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      print('AuthService: Starting login for ${request.email}');
      final response = await _dio.post('/auth/login', data: request.toJson());
      print('AuthService: Login response received, status: ${response.statusCode}');
      
      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (!apiResponse.success || apiResponse.data == null) {
        throw AuthException(apiResponse.message);
      }

      final authResponse = apiResponse.data!;
      print('AuthService: AuthResponse parsed successfully');
      print('AuthService: Tokens - Access: ${authResponse.tokens.accessToken.length}, Refresh: ${authResponse.tokens.refreshToken?.length ?? 0}');
      
      await _saveTokens(authResponse.tokens);
      await _saveUser(authResponse.user);
      print('AuthService: Login completed successfully');

      return authResponse;
    } on DioException catch (e) {
      print('AuthService: DioException during login - Status: ${e.response?.statusCode}, Type: ${e.type}');
      throw _handleDioException(e);
    } catch (e) {
      print('AuthService: Exception during login: $e');
      throw AuthException('Login failed: $e');
    }
  }

  Future<void> logout() async {
    final refreshToken = await getRefreshToken();
    
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      } catch (e) {
        // Continue with local logout even if API call fails
      }
    }

    await clearTokens();
  }

  // New methods for Bloc
  Future<AuthResponse> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    return await login(LoginRequest(email: email, password: password));
  }

  Future<AuthResponse> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    print('=== AuthService registerUser Debug ===');
    print('Creating RegisterRequest with:');
    print('Email: "$email"');
    print('Password: "$password"');
    print('FirstName: "$firstName"');
    print('LastName: "$lastName"');
    print('Phone: "$phone"');
    
    final request = RegisterRequest(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
    
    print('RegisterRequest created successfully');
    print('=====================================');
    
    return await register(request);
  }

  Future<void> sendPhoneVerification(String phone) async {
    try {
      final response = await _dio.post('/auth/phone/send-verification', data: {'phone': phone});
      
      final apiResponse = ApiResponse.fromJson(response.data, (json) => json);
      if (!apiResponse.success) {
        throw AuthException(apiResponse.message);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<AuthResponse> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post('/auth/phone/verify', data: {
        'phone': phone,
        'code': code,
      });
      
      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (!apiResponse.success || apiResponse.data == null) {
        throw AuthException(apiResponse.message);
      }

      final authResponse = apiResponse.data!;
      await _saveTokens(authResponse.tokens);
      await _saveUser(authResponse.user);

      return authResponse;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<AuthResponse> googleSignIn() async {
    print('AuthService: Starting Google Sign-In...');
    final socialResponse = await _socialAuthService.signInWithGoogle();
    if (socialResponse == null) {
      throw const AuthCancelledException('Google Sign-In was cancelled by user');
    }
    
    print('AuthService: Google Sign-In successful, saving tokens...');
    print('AuthService: Tokens - Access: ${socialResponse.tokens.accessToken.length}, Refresh: ${socialResponse.tokens.refreshToken?.length ?? 0}');
    
    // 🔥 CORRECTION: Sauvegarder les tokens et l'utilisateur
    await _saveTokens(socialResponse.tokens);
    await _saveUser(socialResponse.user);
    print('AuthService: Google Sign-In tokens saved successfully');
    
    return socialResponse;
  }

  Future<AuthResponse> appleSignIn() async {
    print('AuthService: Starting Apple Sign-In...');
    final socialResponse = await _socialAuthService.signInWithApple();
    if (socialResponse == null) {
      throw const AuthCancelledException('Apple Sign-In was cancelled by user');
    }
    
    print('AuthService: Apple Sign-In successful, saving tokens...');
    print('AuthService: Tokens - Access: ${socialResponse.tokens.accessToken.length}, Refresh: ${socialResponse.tokens.refreshToken?.length ?? 0}');
    
    // 🔥 CORRECTION: Sauvegarder les tokens et l'utilisateur
    await _saveTokens(socialResponse.tokens);
    await _saveUser(socialResponse.user);
    print('AuthService: Apple Sign-In tokens saved successfully');
    
    return socialResponse;
  }

  Future<AuthResponse> refreshTokens(String s) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      throw AuthException('No refresh token available');
    }

    try {
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      
      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (!apiResponse.success || apiResponse.data == null) {
        await clearTokens();
        throw AuthException(apiResponse.message);
      }

      final authResponse = apiResponse.data!;
      
      // Save new tokens
      await _storage.write(key: 'access_token', value: authResponse.tokens.accessToken);
      await _storage.write(key: 'token_expires_at', value: authResponse.tokens.expiryDate.toIso8601String());
      
      // Save new refresh token if provided
      if (authResponse.tokens.refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: authResponse.tokens.refreshToken!);
      }
      
      await _saveUser(authResponse.user);

      return authResponse;
    } on DioException catch (e) {
      await clearTokens();
      throw _handleDioException(e);
    } catch (e) {
      await clearTokens();
      throw AuthException('Token refresh failed: $e');
    }
  }

  Future<void> verifyPhone(String code) async {
    final token = await getAccessToken();
    if (token == null) throw AuthException('Not authenticated');

    try {
      final response = await _dio.post('/auth/verify-phone',
        data: {'code': code},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      final apiResponse = ApiResponse.fromJson(response.data, (json) => json);

      if (!apiResponse.success) {
        throw AuthException(apiResponse.message);
      }
      
      // Update user data to reflect phone verification
      final user = await getCurrentUser();
      if (user != null) {
        final updatedUser = user.copyWith(phoneVerifiedAt: DateTime.now());
        await _saveUser(updatedUser);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw AuthException('Phone verification failed: $e');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await _dio.post('/auth/forgot-password', data: {'email': email});
      
      final apiResponse = ApiResponse.fromJson(response.data, (json) => json);

      if (!apiResponse.success) {
        throw AuthException(apiResponse.message);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw AuthException('Password reset request failed: $e');
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      final response = await _dio.post('/auth/reset-password', data: {
        'token': token,
        'password': newPassword,
      });
      
      final apiResponse = ApiResponse.fromJson(response.data, (json) => json);

      if (!apiResponse.success) {
        throw AuthException(apiResponse.message);
      }

      // Clear all tokens as they will be invalidated
      await clearTokens();
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw AuthException('Password reset failed: $e');
    }
  }

  Future<User> getCurrentUserFromApi() async {
    final token = await getAccessToken();
    if (token == null) throw AuthException('Not authenticated');

    try {
      final response = await _dio.get('/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => (json as Map<String, dynamic>)['user'],
      );

      if (!apiResponse.success || apiResponse.data == null) {
        throw AuthException(apiResponse.message);
      }

      final user = User.fromJson(apiResponse.data as Map<String, dynamic>);
      await _saveUser(user);

      return user;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw AuthException('Failed to get user data: $e');
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    if (token == null) return false;

    if (await isTokenExpiredStored()) {
      try {
        await refreshTokens('');
        return true;
      } catch (e) {
        return false;
      }
    }

    return true;
  }

  // Ensure valid token (refresh if needed)
  Future<String?> getValidAccessToken() async {
    print('AuthService: getValidAccessToken() - Starting validation...');
    final token = await getAccessToken();
    
    if (token == null) {
      print('AuthService: No access token found in storage');
      return null;
    }
    
    // Vérifier si le token est expiré
    bool expired = isTokenExpired(token);
    print('AuthService: Token expired: $expired');
    
    if (expired) {
      print('AuthService: Token expired, attempting refresh...');
      final refreshToken = await getRefreshToken();
      
      if (refreshToken == null) {
        print('AuthService: No refresh token available, clearing tokens');
        await clearTokens();
        return null;
      }
      
      try {
        await refreshTokens(refreshToken);
        print('AuthService: Token refreshed successfully');
        return await getAccessToken();
      } catch (e) {
        print('AuthService: Token refresh failed: $e');
        await clearTokens();
        return null;
      }
    }

    print('AuthService: Returning valid token');
    return token;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) throw AuthException('Not authenticated');

    try {
      final response = await _dio.put(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      final apiResponse = ApiResponse.fromJson(response.data, (json) => json);

      if (!apiResponse.success) {
        throw AuthException(apiResponse.message);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw AuthException('Password change failed: $e');
    }
  }

  Future<void> deleteAccount({
    required String password,
    required String confirmation,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) throw AuthException('Not authenticated');

    try {
      final response = await _dio.delete(
        '/auth/account',
        data: {
          'password': password,
          'confirmation': confirmation,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      final apiResponse = ApiResponse.fromJson(response.data, (json) => json);

      if (!apiResponse.success) {
        throw AuthException(apiResponse.message);
      }

      // Clear all local data after successful deletion
      await clearTokens();
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw AuthException('Account deletion failed: $e');
    }
  }

  AuthException _handleDioException(DioException e) {
    if (e.response != null && e.response!.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return AuthException(data['message']);
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return AuthException('Connection timeout. Please check your internet connection.');
      case DioExceptionType.connectionError:
        return AuthException('Unable to connect to server. Please check your internet connection.');
      default:
        return AuthException('Network error occurred. Please try again.');
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class AuthCancelledException implements Exception {
  final String message;
  const AuthCancelledException(this.message);

  @override
  String toString() => 'AuthCancelledException: $message';
}