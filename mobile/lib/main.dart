import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/environment.dart';
import 'modules/auth/blocs/bloc.dart';
import 'modules/auth/services/auth_service.dart';
import 'modules/auth/services/phone_auth_service.dart';
import 'modules/notifications/services/firebase_notification_service.dart';
import 'package:dio/dio.dart';

// ✅ Handler pour les messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📱 Message reçu en arrière-plan: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize environment configuration
    await Environment.initialize();
    Environment.printConfig();
    
    // ✅ ÉTAPE 1: Initialiser Firebase
    debugPrint('🚀 Initialisation de Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialisé avec succès');
    
    // ✅ ÉTAPE 2: Configurer les notifications en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // ✅ ÉTAPE 3: Initialisation basique des notifications (sans permissions)
    debugPrint('🔔 Initialisation basique des notifications...');
    await FirebaseNotificationService().initializeBasic();
    
    // Initialize Stripe
    Stripe.publishableKey = Environment.stripePublishableKey;
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

class KiloShareApp extends StatelessWidget {
  const KiloShareApp({super.key});

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
    final router = createRouter();
    
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
          routerConfig: router,
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