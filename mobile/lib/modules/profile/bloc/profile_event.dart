import 'dart:io';
import 'package:equatable/equatable.dart';
import '../models/user_profile.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

// Profile Management Events
class GetUserProfile extends ProfileEvent {
  const GetUserProfile();
}

class CreateUserProfile extends ProfileEvent {
  final Map<String, dynamic> profileData;

  const CreateUserProfile({required this.profileData});

  @override
  List<Object?> get props => [profileData];
}

class UpdateUserProfile extends ProfileEvent {
  final Map<String, dynamic> profileData;

  const UpdateUserProfile({required this.profileData});

  @override
  List<Object?> get props => [profileData];
}

class UploadAvatar extends ProfileEvent {
  final File imageFile;

  const UploadAvatar({required this.imageFile});

  @override
  List<Object?> get props => [imageFile];
}

// Document Management Events
class UploadDocument extends ProfileEvent {
  final File documentFile;
  final String documentType;
  final String? documentNumber;
  final DateTime? expiryDate;

  const UploadDocument({
    required this.documentFile,
    required this.documentType,
    this.documentNumber,
    this.expiryDate,
  });

  @override
  List<Object?> get props => [documentFile, documentType, documentNumber, expiryDate];
}

class GetUserDocuments extends ProfileEvent {
  const GetUserDocuments();
}

class DeleteDocument extends ProfileEvent {
  final int documentId;

  const DeleteDocument({required this.documentId});

  @override
  List<Object?> get props => [documentId];
}

// Badge Management Events
class GetUserBadges extends ProfileEvent {
  const GetUserBadges();
}

// Verification Status Events
class GetVerificationStatus extends ProfileEvent {
  const GetVerificationStatus();
}

// Reset Events
class ResetProfileState extends ProfileEvent {
  const ResetProfileState();
}

class ClearProfileError extends ProfileEvent {
  const ClearProfileError();
}

// Refresh Events
class RefreshProfile extends ProfileEvent {
  const RefreshProfile();
}

class RefreshAllProfileData extends ProfileEvent {
  const RefreshAllProfileData();
}