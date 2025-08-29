import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/journeys/journey_list_screen.dart';
import '../screens/journeys/journey_detail_screen.dart';
import '../screens/journeys/create_journey_screen.dart';
import '../screens/luggage/luggage_list_screen.dart';
import '../screens/luggage/luggage_detail_screen.dart';
import '../screens/luggage/create_luggage_screen.dart';
import '../screens/bookings/booking_list_screen.dart';
import '../screens/bookings/booking_detail_screen.dart';
import '../screens/messages/message_list_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/navigation/main_navigation_screen.dart';

part 'router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash & Onboarding
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      
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
      
      // Main Navigation (Bottom Navigation)
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          // Home
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          
          // Search
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          
          // Bookings
          GoRoute(
            path: '/bookings',
            name: 'bookings',
            builder: (context, state) => const BookingListScreen(),
          ),
          
          // Messages
          GoRoute(
            path: '/messages',
            name: 'messages',
            builder: (context, state) => const MessageListScreen(),
          ),
          
          // Profile
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      
      // Journeys
      GoRoute(
        path: '/journeys',
        name: 'journey-list',
        builder: (context, state) => const JourneyListScreen(),
      ),
      GoRoute(
        path: '/journeys/create',
        name: 'create-journey',
        builder: (context, state) => const CreateJourneyScreen(),
      ),
      GoRoute(
        path: '/journeys/:id',
        name: 'journey-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return JourneyDetailScreen(journeyId: id);
        },
      ),
      
      // Luggage Spaces
      GoRoute(
        path: '/luggage',
        name: 'luggage-list',
        builder: (context, state) => const LuggageListScreen(),
      ),
      GoRoute(
        path: '/luggage/create',
        name: 'create-luggage',
        builder: (context, state) => const CreateLuggageScreen(),
      ),
      GoRoute(
        path: '/luggage/:id',
        name: 'luggage-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LuggageDetailScreen(luggageId: id);
        },
      ),
      
      // Booking Details
      GoRoute(
        path: '/bookings/:id',
        name: 'booking-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BookingDetailScreen(bookingId: id);
        },
      ),
      
      // Chat
      GoRoute(
        path: '/chat/:bookingId',
        name: 'chat',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return ChatScreen(bookingId: bookingId);
        },
      ),
      
      // Profile & Settings
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
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
              onPressed: () => context.go('/home'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
}