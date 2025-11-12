import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static DeepLinkService get instance => _instance;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialiser le service de deep linking
  Future<void> initialize(BuildContext context) async {
    // Gérer le lien initial si l'app a été ouverte via un deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(context, initialUri);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération du lien initial: $e');
    }

    // Écouter les nouveaux liens (quand l'app est déjà ouverte)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(context, uri);
      },
      onError: (err) {
        debugPrint('Erreur de deep link: $err');
      },
    );
  }

  /// Traiter un deep link
  void _handleDeepLink(BuildContext context, Uri uri) {
    debugPrint('Deep link reçu: $uri');

    // Extraire le chemin du deep link
    final path = uri.path;
    final segments = uri.pathSegments;

    if (segments.isEmpty) {
      // Lien vers la page d'accueil
      context.go('/');
      return;
    }

    // Gérer les différents types de deep links
    switch (segments[0]) {
      case 'trips':
        if (segments.length > 1) {
          // Deep link vers un voyage spécifique
          final tripId = segments[1];
          context.go('/trip-details/$tripId');
        } else {
          // Deep link vers la liste des voyages
          context.go('/trips');
        }
        break;

      case 'bookings':
        if (segments.length > 1) {
          // Deep link vers une réservation spécifique
          final bookingId = segments[1];
          context.go('/bookings/$bookingId');
        } else {
          // Deep link vers la liste des réservations
          context.go('/bookings');
        }
        break;

      case 'profile':
        // Deep link vers le profil
        context.go('/profile');
        break;

      case 'verify-email':
        // Deep link pour la vérification d'email
        final token = uri.queryParameters['token'];
        if (token != null) {
          context.go('/verify-email?token=$token');
        }
        break;

      case 'reset-password':
        // Deep link pour réinitialiser le mot de passe
        final token = uri.queryParameters['token'];
        if (token != null) {
          context.go('/reset-password?token=$token');
        }
        break;

      default:
        // Lien non reconnu, rediriger vers l'accueil
        debugPrint('Deep link non reconnu: $path');
        context.go('/');
    }
  }

  /// Nettoyer les ressources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
