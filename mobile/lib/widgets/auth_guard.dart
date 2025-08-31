import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../modules/auth/blocs/auth/auth_bloc.dart';
import '../modules/auth/blocs/auth/auth_state.dart';
import '../modules/auth/models/user_model.dart';

/// Widget qui vérifie l'authentification et redirige si nécessaire
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectTo;
  final Widget? fallback;
  final bool requireAuth;

  const AuthGuard({
    super.key,
    required this.child,
    this.redirectTo,
    this.fallback,
    this.requireAuth = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isAuthenticated = state is AuthAuthenticated;
        
        if (requireAuth && !isAuthenticated) {
          if (redirectTo != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(redirectTo!);
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (fallback != null) {
            return fallback!;
          } else {
            return _buildLoginPrompt(context);
          }
        }
        
        return child;
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Connexion requise',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Vous devez être connecté pour accéder à cette fonctionnalité.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Se connecter'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher du contenu différent selon l'état d'authentification
class AuthAware extends StatelessWidget {
  final Widget authenticatedChild;
  final Widget unauthenticatedChild;

  const AuthAware({
    super.key,
    required this.authenticatedChild,
    required this.unauthenticatedChild,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return authenticatedChild;
        } else {
          return unauthenticatedChild;
        }
      },
    );
  }
}

/// Extension pour faciliter l'accès à l'utilisateur connecté
extension AuthContext on BuildContext {
  bool get isAuthenticated {
    final authState = read<AuthBloc>().state;
    return authState is AuthAuthenticated;
  }

  User? get currentUser {
    final authState = read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user;
    }
    return null;
  }

  String? get accessToken {
    final authState = read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.accessToken;
    }
    return null;
  }
}