import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../models/user_model.dart';

// Import conditionnel pour Apple Sign-In (iOS seulement)
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SimpleSocialAuthService {
  final Dio _dio;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Sur iOS, utiliser le client ID explicite
    // Sur Android, laisser vide pour utiliser google-services.json
    clientId: Platform.isIOS ? '325498754106-2pnias80tkj3c1uvc75c3vonhv1m1bli.apps.googleusercontent.com' : null,
  );

  SimpleSocialAuthService(this._dio);

  /// Authentification avec Google (version simplifiée)
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      print('🔍 Starting Simple Google Sign-In...');
      print('📱 Google Sign-In ClientId: ${_googleSignIn.clientId}');
      
      // Check if user is already signed in
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        print('✅ User already signed in: ${currentUser.email}');
        await _googleSignIn.signOut(); // Force fresh sign-in
      }
      
      // Étape 1: Google Sign-In direct
      print('🚀 Initiating Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Google Sign-In cancelled by user or failed');
        print('💡 Possible causes: Bundle ID mismatch, client ID incorrect, or network issues');
        return null;
      }
      
      print('✅ Google user selected: ${googleUser.email}');
      
      // Étape 2: Obtenir les credentials Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get Google access token');
      }
      
      print('🔑 Google access token obtained');
      
      // Étape 3: Appeler le backend directement avec le token Google
      return await _authenticateWithBackend({
        'access_token': googleAuth.accessToken!,
      }, 'google');
      
    } catch (e) {
      print('❌ Simple Google Sign-In error: $e');
      // Nettoyer en cas d'erreur
      try {
        await _googleSignIn.signOut();
      } catch (cleanupError) {
        print('⚠️ Cleanup error: $cleanupError');
      }
      rethrow;
    }
  }

  /// Authentification avec Apple (version simplifiée)
  Future<AuthResponse?> signInWithApple() async {
    try {
      print('🍎 Starting Simple Apple Sign-In...');
      
      // Vérifier si on est sur iOS
      if (!Platform.isIOS) {
        throw Exception('Apple Sign-In is only available on iOS');
      }
      
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
      
      print('🍎 Apple credentials obtained');
      
      // Appeler le backend directement avec le token Apple
      return await _authenticateWithBackend({
        'id_token': appleCredential.identityToken!,
      }, 'apple');
      
    } catch (e) {
      print('❌ Simple Apple Sign-In error: $e');
      rethrow;
    }
  }

  /// Appeler le backend avec les credentials
  Future<AuthResponse> _authenticateWithBackend(
    Map<String, String> credentials,
    String provider,
  ) async {
    try {
      print('📡 Calling backend API for $provider authentication...');
      
      final response = await _dio.post(
        '/auth/$provider',
        data: credentials,
      );
      
      print('✅ Backend API response received');
      print('📋 Response data: ${response.data}');
      
      if (response.data['success'] != true) {
        throw Exception(
          response.data['message'] ?? 'Authentication failed'
        );
      }
      
      return AuthResponse.fromJson(response.data['data']);
      
    } on DioException catch (e) {
      print('❌ API Error: ${e.response?.data}');
      
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
      print('✅ Simple signout completed');
    } catch (e) {
      print('❌ Simple signout error: $e');
    }
  }
}