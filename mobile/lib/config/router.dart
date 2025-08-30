import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../modules/auth/screens/login_screen.dart';
import '../modules/auth/screens/register_screen.dart';
import '../modules/auth/screens/forgot_password_screen.dart';
import '../modules/auth/screens/email_verification_screen.dart';
import '../modules/auth/screens/phone_auth_screen.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routes: [
      // Authentication
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/email-verification',
        name: 'email-verification',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/phone-auth',
        name: 'phone-auth',
        builder: (context, state) => const PhoneAuthScreen(),
      ),
      
      // Placeholder for home until implemented
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: const Center(
            child: Text('Home Screen - Coming Soon'),
          ),
        ),
      ),
    ],
    
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    ),
  );
}