import 'dart:convert';
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
      
      
      // Extraire les données du token JWT
      String userIdentifier = appleCredential.userIdentifier ?? '';
      String? email = appleCredential.email;
      String? name = appleCredential.givenName != null && appleCredential.familyName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName}'
          : appleCredential.givenName ?? appleCredential.familyName;

      // Extraire les données manquantes du token JWT
      try {
        final parts = appleCredential.identityToken!.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalizedPayload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
          final decoded = utf8.decode(base64Decode(normalizedPayload));
          final claims = jsonDecode(decoded);

          // Utiliser user_identifier du JWT si pas disponible
          if (userIdentifier.isEmpty) {
            userIdentifier = claims['sub'] ?? '';
          }

          // Utiliser email du JWT si pas disponible directement
          if (email == null || email.isEmpty) {
            email = claims['email'];
          }
        }
      } catch (e) {
        // Si extraction échoue pour userIdentifier, utiliser une valeur par défaut
        if (userIdentifier.isEmpty) {
          userIdentifier = 'apple_user_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // Appeler le backend directement avec le token Apple
      return await _authenticateWithBackend({
        'identity_token': appleCredential.identityToken!,
        'user_identifier': userIdentifier,
        'email': email,
        'name': name,
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
    Map<String, String?> credentials,
    String provider,
  ) async {
    try {
      
      // Filtrer les valeurs nulles
      final filteredCredentials = Map<String, dynamic>.fromEntries(
        credentials.entries.where((entry) => entry.value != null)
      );

      final response = await _dio.post(
        '/auth/$provider',
        data: filteredCredentials,
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
      // Ignore sign out errors
    }
  }
}