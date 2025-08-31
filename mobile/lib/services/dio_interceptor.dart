import 'package:dio/dio.dart';
import '../modules/auth/services/auth_service.dart';

class AuthInterceptor extends Interceptor {
  final AuthService _authService;

  AuthInterceptor(this._authService);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _addAuthToken(options).then((_) {
      handler.next(options);
    }).catchError((e) {
      print('Error in auth interceptor: $e');
      handler.next(options);
    });
  }

  Future<void> _addAuthToken(RequestOptions options) async {
    try {
      // Ajouter automatiquement le token d'authentification
      final token = await _authService.getValidAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        print('Auth token added to request: ${token.substring(0, 20)}...');
      } else {
        print('No auth token available for request');
      }
    } catch (e) {
      print('Error adding auth token: $e');
      // Continuer sans token si erreur
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Si erreur 401, essayer de refresh le token
    if (err.response?.statusCode == 401) {
      _handle401Error(err, handler);
    } else {
      handler.next(err);
    }
  }

  void _handle401Error(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken != null) {
        await _authService.refreshTokens(refreshToken);
        
        // Retry la requête originale avec le nouveau token
        final newToken = await _authService.getValidAccessToken();
        if (newToken != null) {
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          
          final response = await Dio().fetch(options);
          handler.resolve(response);
          return;
        }
      }
      
      // Si le refresh échoue, nettoyer les tokens
      await _authService.clearTokens();
    } catch (e) {
      await _authService.clearTokens();
    }
    
    handler.next(err);
  }
}