import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../modules/auth/screens/login_screen.dart';
import '../modules/auth/screens/register_screen.dart';
import '../modules/auth/screens/forgot_password_screen.dart';
import '../modules/auth/screens/email_verification_screen.dart';
import '../modules/auth/screens/phone_auth_screen.dart';
import '../modules/auth/screens/reset_password_screen.dart';
import '../modules/home/screens/home_screen.dart';
import '../modules/profile/screens/user_settings_screen.dart';
import '../modules/profile/screens/change_password_screen.dart';
import '../modules/profile/screens/notification_settings_screen_enhanced.dart';
import '../modules/profile/screens/privacy_settings_screen.dart';
import '../modules/profile/screens/delete_account_screen.dart';
import '../modules/profile/screens/linked_accounts_screen.dart';
import '../modules/profile/screens/edit_profile_screen.dart';
import '../modules/profile/screens/trip_history_screen.dart';
import '../modules/trips/screens/trip_type_selection_screen.dart';
import '../modules/trips/screens/create_trip_screen.dart';
import '../modules/trips/screens/my_trips_screen.dart';
import '../modules/trips/screens/trip_details_final.dart';
import '../modules/trips/screens/search_trips_screen.dart';
import '../modules/booking/screens/bookings_list_screen.dart';
import '../modules/booking/screens/booking_details_screen.dart';
import '../modules/messaging/screens/conversation_screen.dart';
import '../modules/profile/screens/wallet_screen.dart';
import '../modules/profile/screens/public_user_profile_screen.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    // Handle deep links by converting kiloshare:// scheme to paths
    redirect: (context, state) {
      final uri = state.uri;

      // If the URI has kiloshare scheme, reconstruct the proper path
      if (uri.scheme == 'kiloshare') {
        debugPrint('🔗 Router redirect - Converting kiloshare:// to path');
        debugPrint('🔗 Original URI: $uri');
        debugPrint('🔗 Host: ${uri.host}, Path: ${uri.path}');

        // Combine host and path: kiloshare://profile/wallet -> /profile/wallet
        String path = '';
        if (uri.host.isNotEmpty) {
          path = '/${uri.host}${uri.path}';
        } else {
          path = uri.path;
        }

        // Ensure path starts with /
        if (!path.startsWith('/')) {
          path = '/$path';
        }

        debugPrint('🔗 Redirecting to: $path');
        return path;
      }

      return null; // No redirect needed
    },
    routes: [
      // Root redirect to home
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
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
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(token: token);
        },
      ),
      
      // Main App
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Profile routes
      GoRoute(
        path: '/profile/settings',
        name: 'profile-settings',
        builder: (context, state) => const UserSettingsScreen(),
      ),
      GoRoute(
        path: '/profile/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        name: 'notification-settings',
        builder: (context, state) => const NotificationSettingsScreenEnhanced(),
      ),
      GoRoute(
        path: '/profile/privacy',
        name: 'privacy-settings',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/profile/linked-accounts',
        name: 'linked-accounts',
        builder: (context, state) => const LinkedAccountsScreen(),
      ),
      GoRoute(
        path: '/profile/delete-account',
        name: 'delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/trip-history',
        name: 'trip-history',
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: '/profile/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/users/:userId/profile',
        name: 'public-user-profile',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final userName = state.uri.queryParameters['userName'];
          return PublicUserProfileScreen(
            userId: userId,
            userName: userName,
          );
        },
      ),

      // Trip routes
      GoRoute(
        path: '/trips/create',
        name: 'create-trip',
        builder: (context, state) => const TripTypeSelectionScreen(),
      ),
      GoRoute(
        path: '/trips/my-trips',
        name: 'my-trips',
        builder: (context, state) => const MyTripsScreen(),
      ),
      GoRoute(
        path: '/trips/search',
        name: 'search-trips',
        builder: (context, state) => const SearchTripsScreen(),
      ),
      GoRoute(
        path: '/trips/:id',
        name: 'trip-details',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return TripDetailsFinal(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trips/edit/:id',
        name: 'edit-trip',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return CreateTripScreen(tripId: tripId);
        },
      ),
      
      // Booking routes
      GoRoute(
        path: '/bookings',
        name: 'bookings',
        builder: (context, state) => const BookingsListScreen(),
      ),
      GoRoute(
        path: '/bookings/:id',
        name: 'booking-details',
        builder: (context, state) {
          final bookingId = state.pathParameters['id']!;
          return BookingDetailsScreen(bookingId: bookingId);
        },
      ),
      
      // Messaging routes
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        builder: (context, state) {
          final tripId = state.uri.queryParameters['tripId']!;
          final tripOwnerId = state.uri.queryParameters['tripOwnerId']!;
          final tripTitle = state.uri.queryParameters['tripTitle'] ?? 'Conversation';
          return ConversationScreen(
            tripId: tripId,
            tripOwnerId: tripOwnerId,
            tripTitle: tripTitle,
          );
        },
      ),
    ],
    
    errorBuilder: (context, state) {
      // Log detailed error information
      debugPrint('❌ Router Error - Location: ${state.uri}');
      debugPrint('❌ Router Error - Error: ${state.error}');
      debugPrint('❌ Router Error - MatchedLocation: ${state.matchedLocation}');

      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  'Path: ${state.uri}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  state.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
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
    },
  );
}