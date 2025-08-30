import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiloshare/modules/auth/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({required AuthService authService})
      : _authService = authService,
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
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthTokenRefreshRequested>(_onAuthTokenRefreshRequested);
    on<AuthErrorCleared>(_onAuthErrorCleared);
    on<SocialSignInRequested>(_onSocialSignInRequested);
  }

  Future<void> _onAuthStarted(
      AuthStarted event, Emitter<AuthState> emit) async {
    try {
      // Check if user is already authenticated
      final token = await _authService.getStoredToken();
      if (token != null && !_authService.isTokenExpired(token)) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          emit(AuthAuthenticated(
            user: user,
            accessToken: token,
          ));
          return;
        }
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
        emit(AuthAuthenticated(
          user: response.user,
          accessToken: response.tokens.accessToken,
          refreshToken: response.tokens.refreshToken,
        ));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
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
        emit(AuthAuthenticated(
          user: response.user,
          accessToken: response.tokens.accessToken,
          refreshToken: response.tokens.refreshToken,
        ));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
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
      emit(AuthError(message: e.toString()));
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
      emit(AuthError(message: e.toString()));
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
      emit(AuthError(message: e.toString()));
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
    } catch (e) {
      emit(AuthError(message: e.toString()));
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
    } catch (e) {
      emit(AuthError(message: e.toString()));
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
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthUnauthenticated()); // Logout anyway
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
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  void _onAuthErrorCleared(AuthErrorCleared event, Emitter<AuthState> emit) {
    if (state is AuthError) {
      emit(AuthUnauthenticated());
    }
  }
}
