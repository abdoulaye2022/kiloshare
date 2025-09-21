import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart';

class SocialAuthService {
  final Dio _dio;
  
  SocialAuthService(this._dio);
  
  // Configuration Google Sign-In
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Client ID pour Android (trouvé dans google-services.json)
    serverClientId: '325498754106-ocf60iqo99m4la6viaahfkvc0c9pcs4k.apps.googleusercontent.com',
  );
  
  /// Authentification avec Google
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      
      // Vérifier si Google Sign-In est disponible
      await _googleSignIn.isSignedIn();
      
      // Déconnecter silencieusement sans lever d'exception
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Continue anyway
      }
      
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
      
      if (googleAccount == null) {
        return null;
      }
      
      
      final GoogleSignInAuthentication googleAuth = await googleAccount.authentication;
      
      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get Google access token');
      }
      
      
      // Appeler l'API backend
      return await _authenticateWithProvider(
        'google',
        {'access_token': googleAuth.accessToken!},
      );
      
    } catch (e) {
      rethrow;
    }
  }
  
  
  /// Authentification avec Apple
  Future<AuthResponse?> signInWithApple() async {
    try {
      
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: dotenv.env['APPLE_CLIENT_ID'] ?? 'com.kiloshare.app',
          redirectUri: Uri.parse('https://kiloshare.com/auth/apple/callback'),
        ),
      );
      
      
      // Appeler l'API backend
      return await _authenticateWithProvider(
        'apple',
        {'id_token': credential.identityToken!},
      );
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Appeler l'API backend pour l'authentification
  Future<AuthResponse> _authenticateWithProvider(
    String provider,
    Map<String, String> credentials,
  ) async {
    try {
      
      final response = await _dio.post(
        '/auth/$provider',
        data: credentials,
      );
      
      
      if (response.data['success'] != true) {
        throw Exception(
          response.data['message'] ?? 'Authentication failed'
        );
      }
      
      return AuthResponse.fromJson(response.data['data']);
      
    } on DioException catch (e) {
      
      if (e.response?.data != null && e.response!.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      
      throw Exception('Network error during authentication');
    }
  }
  
  /// Obtenir les providers disponibles
  Future<Map<String, dynamic>> getAvailableProviders() async {
    try {
      final response = await _dio.get('/auth/social/providers');
      
      if (response.data['success'] == true) {
        return response.data['data']['providers'] ?? {};
      }
      
      return {};
    } catch (e) {
      return {};
    }
  }
  
  /// Lier un compte social à un utilisateur existant
  Future<bool> linkSocialAccount(String provider, Map<String, String> credentials) async {
    try {
      final response = await _dio.post(
        '/auth/social/link',
        data: {
          'provider': provider,
          ...credentials,
        },
      );
      
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Délier un compte social
  Future<bool> unlinkSocialAccount(String provider) async {
    try {
      final response = await _dio.delete('/auth/social/unlink/$provider');
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Déconnexion de tous les providers sociaux
  Future<void> signOutFromAllProviders() async {
    try {
      // Google Sign-Out
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      
      // Apple Sign-Out (pas de méthode spécifique nécessaire)
      
    } catch (e) {
    }
  }
}