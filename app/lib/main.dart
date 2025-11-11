import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'firebase_options.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/environment_config.dart';
import 'modules/auth/blocs/bloc.dart';
import 'modules/auth/services/auth_service.dart';
import 'modules/auth/services/phone_auth_service.dart';
import 'modules/notifications/services/firebase_notification_service.dart';
import 'package:dio/dio.dart';

// ✅ Handler pour les messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize environment configuration
    await EnvironmentConfig.initialize();
    // EnvironmentConfig.printConfig(); // Disabled for production
    
    // ✅ ÉTAPE 1: Initialiser Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // ✅ ÉTAPE 2: Configurer les notifications en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // ✅ ÉTAPE 3: Initialisation basique des notifications (sans permissions)
    await FirebaseNotificationService().initializeBasic();
    
    // Initialize Stripe
    Stripe.publishableKey = EnvironmentConfig.stripePublishableKey;
    Stripe.merchantIdentifier = 'merchant.com.kiloshare.app';
    await Stripe.instance.applySettings();
    
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    runApp(const KiloShareApp());
  } catch (e) {
    debugPrint('❌ Erreur lors de l\'initialisation: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

class KiloShareApp extends StatefulWidget {
  const KiloShareApp({super.key});

  @override
  State<KiloShareApp> createState() => _KiloShareAppState();
}

class _KiloShareAppState extends State<KiloShareApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  late final GoRouter _router;
  bool _initialLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _router = createRouter();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 Deep link received: $uri');
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('❌ Deep link error: $err');
    });

    // Check if app was launched via deep link (cold start)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && !_initialLinkHandled) {
        debugPrint('🔗 Initial deep link: $uri');
        _initialLinkHandled = true;
        // Delay to ensure router and app are fully ready
        Future.delayed(const Duration(milliseconds: 1500), () {
          debugPrint('🔗 Router ready, processing initial deep link');
          _handleDeepLink(uri);
        });
      } else if (_initialLinkHandled) {
        debugPrint('🔗 Initial link already handled, ignoring (hot reload detected)');
      }
    } catch (e) {
      debugPrint('❌ Failed to get initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Deep link received - Full URI: ${uri.toString()}');
    debugPrint('🔗 URI Details:');
    debugPrint('   - Scheme: ${uri.scheme}');
    debugPrint('   - Host: ${uri.host}');
    debugPrint('   - Path: ${uri.path}');
    debugPrint('   - PathSegments: ${uri.pathSegments}');

    String path = '';

    // For custom scheme kiloshare://profile/wallet
    // uri.host = "profile", uri.path = "/wallet"
    if (uri.scheme == 'kiloshare') {
      debugPrint('🔗 Processing kiloshare:// scheme');
      // Combine host and path: profile + /wallet = /profile/wallet
      if (uri.host.isNotEmpty) {
        path = '/${uri.host}${uri.path}';
        debugPrint('🔗 Combined host and path: $path');
      } else {
        path = uri.path;
        debugPrint('🔗 Using path only: $path');
      }
    } else {
      debugPrint('🔗 Processing ${uri.scheme}:// scheme');
      // For https://kiloshare.com/profile/wallet
      // uri.path already contains the full path
      path = uri.path;
    }

    // Ensure path starts with /
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    debugPrint('🔗 Final navigation path: $path');

    // Navigate using the router instance with error handling
    try {
      debugPrint('🔗 Attempting navigation to: $path');
      _router.go(path);
      debugPrint('✅ Navigation successful to: $path');
    } catch (e, stackTrace) {
      debugPrint('❌ Navigation failed to: $path');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      // Fallback: try going to home if navigation fails
      try {
        debugPrint('🔄 Attempting fallback navigation to /home');
        _router.go('/home');
      } catch (fallbackError) {
        debugPrint('❌ Fallback navigation also failed: $fallbackError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) {
            final dio = Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ));

            // Add logging interceptor
            dio.interceptors.add(LogInterceptor(
              requestBody: true,
              responseBody: true,
              logPrint: (obj) => debugPrint(obj.toString()),
            ));

            return AuthBloc(
              authService: AuthService.instance,
              phoneAuthService: PhoneAuthService(dio),
            )..add(AuthStarted());
          },
        ),
      ],
      child: _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: _router,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr', 'FR'),
            Locale('en', 'US'),
          ],
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String? error;

  const ErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Impossible de démarrer l\'application',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart functionality could be implemented here
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}