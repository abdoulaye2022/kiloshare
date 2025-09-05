import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiloshare/modules/auth/services/auth_service.dart';
import '../../services/phone_auth_service.dart';
import '../../../../services/auth_token_service.dart';
import '../../../../services/logout_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final PhoneAuthService _phoneAuthService;

  AuthBloc({
    required AuthService authService,
    required PhoneAuthService phoneAuthService,
  })  : _authService = authService,
        _phoneAuthService = phoneAuthService,
        super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthPhoneLoginRequested>(_onAuthPhoneLoginRequested);
    on<AuthPhoneRegisterRequested>(_onAuthPhoneRegisterRequested);
    on<AuthSMSVerificationRequested>(_onAuthSMSVerificationRequested);
    on<AuthGoogleLoginRequested>(_onAuthGoogleLoginRequested);
    on<AuthAppleLoginRequested>(_onAuthAppleLoginRequested);
    on<AuthForgotPasswordRequested>(_onAuthForgotPasswordRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthTokenRefreshRequested>(_onAuthTokenRefreshRequested);
    on<AuthUserUpdated>(_onAuthUserUpdated);
    on<AuthErrorCleared>(_onAuthErrorCleared);
    on<SocialSignInRequested>(_onSocialSignInRequested);
    
    // Nouveaux handlers pour l'authentification par téléphone
    on<SendPhoneVerificationCode>(_onSendPhoneVerificationCode);
    on<VerifyPhoneCode>(_onVerifyPhoneCode);
  }

  /// Helper method to extract user-friendly error messages
  String _extractErrorMessage(Object e) {
    if (e.toString().contains('AuthException:')) {
      // Extract message after "AuthException: "
      String fullError = e.toString();
      if (fullError.contains('AuthException: ')) {
        return fullError.split('AuthException: ')[1];
      }
    }
    return e.toString();
  }

  Future<void> _onAuthStarted(
      AuthStarted event, Emitter<AuthState> emit) async {
    try {
      // Check if user is already authenticated
      final token = await _authService.getStoredToken();
      
      if (token != null && !_authService.isTokenExpired(token)) {
        var user = await _authService.getCurrentUser();
        
        // Si pas d'utilisateur en local, récupérer depuis l'API
        if (user == null) {
          try {
            user = await _authService.getCurrentUserFromApi();
            // Sauvegarder l'utilisateur récupéré
            await _authService.saveUser(user);
          } catch (e) {
            // Si échec de récupération, considérer comme non authentifié
            emit(AuthUnauthenticated());
            return;
          }
        }
        
        emit(AuthAuthenticated(
          user: user,
          accessToken: token,
        ));
        return;
      }
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.loginWithCredentials(
        email: event.email,
        password: event.password,
      );

      // Check if user needs email verification
      if (!response.user.isVerified) {
        emit(AuthEmailVerificationRequired(
          user: response.user,
          accessToken: response.tokens.accessToken,
          refreshToken: response.tokens.refreshToken,
        ));
      } else {
        // Store token in AuthTokenService for API calls
        await AuthTokenService.instance.setToken(response.tokens.accessToken);
        
        emit(AuthAuthenticated(
          user: response.user,
          accessToken: response.tokens.accessToken,
          refreshToken: response.tokens.refreshToken,
        ));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.registerUser(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
      );

      // Check if user needs email verification
      if (!response.user.isVerified) {
        emit(AuthEmailVerificationRequired(
          user: response.user,
          accessToken: response.tokens.accessToken,
          refreshToken: response.tokens.refreshToken,
        ));
      } else {
        // Store token in AuthTokenService for API calls
        await AuthTokenService.instance.setToken(response.tokens.accessToken);
        
        emit(AuthAuthenticated(
          user: response.user,
          accessToken: response.tokens.accessToken,
          refreshToken: response.tokens.refreshToken,
        ));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthPhoneLoginRequested(
    AuthPhoneLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Simulate sending SMS code
      await _authService.sendPhoneVerification(event.phone);

      emit(AuthPhoneVerificationRequired(
        phone: event.phone,
        verificationId: 'temp_verification_id',
      ));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthPhoneRegisterRequested(
    AuthPhoneRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Send SMS verification for phone registration
      await _authService.sendPhoneVerification(event.phone);

      emit(AuthPhoneVerificationRequired(
        phone: event.phone,
        verificationId: 'temp_verification_id',
      ));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthSMSVerificationRequested(
    AuthSMSVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.verifyPhoneCode(
        phone: event.phone,
        code: event.code,
      );

      emit(AuthAuthenticated(
        user: response.user,
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
      ));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthGoogleLoginRequested(
    AuthGoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthSocialLoginInProgress(provider: 'google'));
    try {
      final response = await _authService.googleSignIn();

      emit(AuthAuthenticated(
        user: response.user,
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
      ));
    } on AuthCancelledException {
      // User cancelled Google Sign-In, return to unauthenticated state silently
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }


  Future<void> _onAuthAppleLoginRequested(
    AuthAppleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthSocialLoginInProgress(provider: 'apple'));
    try {
      final response = await _authService.appleSignIn();

      emit(AuthAuthenticated(
        user: response.user,
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
      ));
    } on AuthCancelledException {
      // User cancelled Apple Sign-In, return to unauthenticated state silently
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.forgotPassword(event.email);
      emit(AuthPasswordResetSent(email: event.email));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.resetPassword(event.token, event.newPassword);
      emit(const AuthPasswordResetSuccess());
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Utiliser le service centralisé de déconnexion pour vider tous les états persistés
      await LogoutService.performCompleteLogout();
      emit(AuthUnauthenticated());
    } catch (e) {
      // Même en cas d'erreur, émettre l'état non authentifié
      // Le nettoyage local forcé a probablement eu lieu
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthTokenRefreshRequested(
    AuthTokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) return;

    final currentState = state as AuthAuthenticated;
    try {
      final response = await _authService.refreshTokens('');

      emit(AuthAuthenticated(
        user: currentState.user,
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
      ));
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSocialSignInRequested(
    SocialSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthSocialLoginInProgress(provider: event.provider));
    try {
      switch (event.provider) {
        case 'google':
          // Use the social auth service to handle Google sign-in
          final response = await _authService.googleSignIn();
          emit(AuthAuthenticated(
            user: response.user,
            accessToken: response.tokens.accessToken,
            refreshToken: response.tokens.refreshToken,
          ));
          break;
        case 'apple':
          // Use the social auth service to handle Apple sign-in
          final response = await _authService.appleSignIn();
          emit(AuthAuthenticated(
            user: response.user,
            accessToken: response.tokens.accessToken,
            refreshToken: response.tokens.refreshToken,
          ));
          break;
        default:
          throw Exception('Unsupported provider: ${event.provider}');
      }
    } on AuthCancelledException {
      // User cancelled social sign-in, return to unauthenticated state silently
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  void _onAuthErrorCleared(AuthErrorCleared event, Emitter<AuthState> emit) {
    if (state is AuthError) {
      emit(AuthUnauthenticated());
    }
  }

  // Handlers pour l'authentification par téléphone
  Future<void> _onSendPhoneVerificationCode(
    SendPhoneVerificationCode event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _phoneAuthService.sendVerificationCode(event.phoneNumber);
      
      if (result.success) {
        emit(PhoneCodeSent(phoneNumber: result.phoneNumber ?? event.phoneNumber));
      } else {
        emit(AuthError(message: result.message));
      }
    } catch (e) {
      emit(AuthError(message: 'Erreur lors de l\'envoi du SMS: ${e.toString()}'));
    }
  }

  Future<void> _onVerifyPhoneCode(
    VerifyPhoneCode event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _phoneAuthService.verifyCodeAndLogin(
        phoneNumber: event.phoneNumber,
        code: event.code,
        firstName: event.firstName,
        lastName: event.lastName,
      );
      
      emit(AuthAuthenticated(
        user: response.user,
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
      ));
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onAuthUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(AuthAuthenticated(
        user: event.user,
        accessToken: currentState.accessToken,
        refreshToken: currentState.refreshToken,
      ));
    }
  }
}
