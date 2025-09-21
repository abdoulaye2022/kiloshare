import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../models/user_model.dart';

class SimpleSocialAuthService {
  final Dio _dio;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // iOS needs clientId, Android needs serverClientId
    clientId: Platform.isIOS ? '325498754106-2pnias80tkj3c1uvc75c3vonhv1m1bli.apps.googleusercontent.com' : null,
    serverClientId: '325498754106-ocf60iqo99m4la6viaahfkvc0c9pcs4k.apps.googleusercontent.com',
  );

  SimpleSocialAuthService(this._dio);

  /// Authentification avec Google (version simplifiée)
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      
      // Check if user is already signed in
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        await _googleSignIn.signOut(); // Force fresh sign-in
      }
      
      // Étape 1: Google Sign-In direct
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null; // User cancelled, return null gracefully
      }
      
      
      // Étape 2: Obtenir les credentials Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get Google access token');
      }
      
      
      // Étape 3: Appeler le backend directement avec le token Google
      return await _authenticateWithBackend({
        'access_token': googleAuth.accessToken!,
      }, 'google');
      
    } catch (e) {
      // Nettoyer en cas d'erreur
      try {
        await _googleSignIn.signOut();
      } catch (cleanupError) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  /// Authentification avec Apple (version simplifiée)
  Future<AuthResponse?> signInWithApple() async {
    try {
      
      // Apple Sign-In direct
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      if (appleCredential.identityToken == null) {
        throw Exception('Failed to get Apple ID token');
      }
      
      
      // Appeler le backend directement avec le token Apple
      return await _authenticateWithBackend({
        'id_token': appleCredential.identityToken!,
      }, 'apple');
      
    } catch (e) {
      // Vérifier si c'est une annulation utilisateur
      if (e.toString().contains('AuthorizationErrorCode.canceled') || 
          e.toString().contains('error 1001')) {
        return null; // Retourner null au lieu de throw pour annulation
      }
      
      rethrow;
    }
  }

  /// Appeler le backend avec les credentials
  Future<AuthResponse> _authenticateWithBackend(
    Map<String, String> credentials,
    String provider,
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

  /// Déconnexion simple
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
    }
  }
}