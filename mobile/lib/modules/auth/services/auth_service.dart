import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'simple_social_auth_service.dart';
import '../../../config/app_config.dart';

class AuthService {
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

  AuthService({Dio? dio}) : _dio = dio ?? _createDio() {
    _socialAuthService = SimpleSocialAuthService(_dio);
  }

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

    return dio;
  }

  // Token management
  Future<void> _saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: 'access_token', value: tokens.accessToken),
      if (tokens.refreshToken != null)
        _storage.write(key: 'refresh_token', value: tokens.refreshToken!),
      _storage.write(key: 'token_expires_at', value: tokens.expiryDate.toIso8601String()),
    ]);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<String?> getStoredToken() async {
    return await getAccessToken();
  }

  bool isTokenExpired(String token) {
    // Simple JWT token expiry check
    // In production, decode JWT and check exp claim
    return false; // Placeholder for now
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
        ),
      );
      
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
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login', data: request.toJson());
      
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
    } catch (e) {
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
    final socialResponse = await _socialAuthService.signInWithGoogle();
    if (socialResponse == null) {
      throw const AuthException('Google Sign-In was cancelled');
    }
    return socialResponse;
  }

  Future<AuthResponse> appleSignIn() async {
    final socialResponse = await _socialAuthService.signInWithApple();
    if (socialResponse == null) {
      throw const AuthException('Apple Sign-In was cancelled');
    }
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
      
      // Save new access token (refresh token usually stays the same)
      await _storage.write(key: 'access_token', value: authResponse.tokens.accessToken);
      await _storage.write(key: 'token_expires_at', value: authResponse.tokens.expiryDate.toIso8601String());
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
    if (await isTokenExpiredStored()) {
      try {
        await refreshTokens('');
      } catch (e) {
        return null;
      }
    }

    return await getAccessToken();
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