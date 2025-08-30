import 'package:equatable/equatable.dart';
import '../models/user_profile.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

// Initial State
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

// Loading States
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileActionLoading extends ProfileState {
  final String action;

  const ProfileActionLoading({required this.action});

  @override
  List<Object?> get props => [action];
}

// Success States
class ProfileLoaded extends ProfileState {
  final UserProfile? profile;
  final List<VerificationDocument> documents;
  final List<TrustBadge> badges;
  final VerificationStatus verificationStatus;

  const ProfileLoaded({
    this.profile,
    this.documents = const [],
    this.badges = const [],
    required this.verificationStatus,
  });

  @override
  List<Object?> get props => [profile, documents, badges, verificationStatus];

  ProfileLoaded copyWith({
    UserProfile? profile,
    List<VerificationDocument>? documents,
    List<TrustBadge>? badges,
    VerificationStatus? verificationStatus,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      documents: documents ?? this.documents,
      badges: badges ?? this.badges,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}

class ProfileCreated extends ProfileState {
  final UserProfile profile;

  const ProfileCreated({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class ProfileUpdated extends ProfileState {
  final UserProfile profile;

  const ProfileUpdated({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class AvatarUploaded extends ProfileState {
  final String avatarUrl;

  const AvatarUploaded({required this.avatarUrl});

  @override
  List<Object?> get props => [avatarUrl];
}

class DocumentUploaded extends ProfileState {
  final VerificationDocument document;

  const DocumentUploaded({required this.document});

  @override
  List<Object?> get props => [document];
}

class DocumentDeleted extends ProfileState {
  final int documentId;

  const DocumentDeleted({required this.documentId});

  @override
  List<Object?> get props => [documentId];
}

class DocumentsLoaded extends ProfileState {
  final List<VerificationDocument> documents;

  const DocumentsLoaded({required this.documents});

  @override
  List<Object?> get props => [documents];
}

class BadgesLoaded extends ProfileState {
  final List<TrustBadge> badges;

  const BadgesLoaded({required this.badges});

  @override
  List<Object?> get props => [badges];
}

class VerificationStatusLoaded extends ProfileState {
  final VerificationStatus verificationStatus;

  const VerificationStatusLoaded({required this.verificationStatus});

  @override
  List<Object?> get props => [verificationStatus];
}

// Error States
class ProfileError extends ProfileState {
  final String message;
  final String? errorCode;
  final Object? error;

  const ProfileError({
    required this.message,
    this.errorCode,
    this.error,
  });

  @override
  List<Object?> get props => [message, errorCode, error];
}

class ProfileActionError extends ProfileState {
  final String message;
  final String action;
  final String? errorCode;
  final Object? error;

  const ProfileActionError({
    required this.message,
    required this.action,
    this.errorCode,
    this.error,
  });

  @override
  List<Object?> get props => [message, action, errorCode, error];
}

// No Profile State
class NoProfile extends ProfileState {
  const NoProfile();
}

// Partial Data States (for when some operations succeed and others fail)
class ProfilePartiallyLoaded extends ProfileState {
  final UserProfile? profile;
  final List<VerificationDocument>? documents;
  final List<TrustBadge>? badges;
  final VerificationStatus? verificationStatus;
  final List<String> errors;

  const ProfilePartiallyLoaded({
    this.profile,
    this.documents,
    this.badges,
    this.verificationStatus,
    this.errors = const [],
  });

  @override
  List<Object?> get props => [profile, documents, badges, verificationStatus, errors];
}

// Convenience getters for checking state types
extension ProfileStateX on ProfileState {
  bool get isLoading => this is ProfileLoading || this is ProfileActionLoading;
  bool get isError => this is ProfileError || this is ProfileActionError;
  bool get hasProfile => this is ProfileLoaded && (this as ProfileLoaded).profile != null;
  bool get hasData => this is ProfileLoaded;
  
  UserProfile? get profile {
    if (this is ProfileLoaded) {
      return (this as ProfileLoaded).profile;
    }
    return null;
  }
  
  List<VerificationDocument> get documents {
    if (this is ProfileLoaded) {
      return (this as ProfileLoaded).documents;
    }
    return [];
  }
  
  List<TrustBadge> get badges {
    if (this is ProfileLoaded) {
      return (this as ProfileLoaded).badges;
    }
    return [];
  }
  
  VerificationStatus? get verificationStatus {
    if (this is ProfileLoaded) {
      return (this as ProfileLoaded).verificationStatus;
    }
    return null;
  }
}