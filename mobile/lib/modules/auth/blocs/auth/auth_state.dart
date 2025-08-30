import 'package:equatable/equatable.dart';
import 'package:kiloshare/modules/auth/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final String accessToken;
  final String? refreshToken;

  const AuthAuthenticated({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  @override
  List<Object?> get props => [user, accessToken, refreshToken];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final String? errorCode;

  const AuthError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

class AuthPhoneVerificationRequired extends AuthState {
  final String phone;
  final String verificationId;

  const AuthPhoneVerificationRequired({
    required this.phone,
    required this.verificationId,
  });

  @override
  List<Object?> get props => [phone, verificationId];
}

class AuthPasswordResetSent extends AuthState {
  final String email;

  const AuthPasswordResetSent({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthSocialLoginInProgress extends AuthState {
  final String provider; // 'google', 'apple'

  const AuthSocialLoginInProgress({required this.provider});

  @override
  List<Object?> get props => [provider];
}

class AuthEmailVerificationRequired extends AuthState {
  final User user;
  final String accessToken;
  final String? refreshToken;

  const AuthEmailVerificationRequired({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  @override
  List<Object?> get props => [user, accessToken, refreshToken];
}
