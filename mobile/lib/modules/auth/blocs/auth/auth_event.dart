import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? phone;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.phone,
  });

  @override
  List<Object?> get props => [email, password, firstName, lastName, phone];
}

class AuthPhoneLoginRequested extends AuthEvent {
  final String phone;

  const AuthPhoneLoginRequested({required this.phone});

  @override
  List<Object?> get props => [phone];
}

class AuthPhoneRegisterRequested extends AuthEvent {
  final String phone;
  final String name;

  const AuthPhoneRegisterRequested({
    required this.phone,
    required this.name,
  });

  @override
  List<Object?> get props => [phone, name];
}

class AuthSMSVerificationRequested extends AuthEvent {
  final String phone;
  final String code;

  const AuthSMSVerificationRequested({
    required this.phone,
    required this.code,
  });

  @override
  List<Object?> get props => [phone, code];
}

class AuthGoogleLoginRequested extends AuthEvent {}


class AuthAppleLoginRequested extends AuthEvent {}

class AuthForgotPasswordRequested extends AuthEvent {
  final String email;

  const AuthForgotPasswordRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthTokenRefreshRequested extends AuthEvent {}

class AuthErrorCleared extends AuthEvent {}

final class SocialSignInRequested extends AuthEvent {
  final String provider;
  
  const SocialSignInRequested(this.provider);
  
  @override
  List<Object> get props => [provider];
}