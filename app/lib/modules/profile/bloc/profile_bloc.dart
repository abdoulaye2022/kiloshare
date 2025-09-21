import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileService _profileService;

  ProfileBloc({required ProfileService profileService})
      : _profileService = profileService,
        super(const ProfileInitial()) {
    
    // Profile Management
    on<GetUserProfile>(_onGetUserProfile);
    on<CreateUserProfile>(_onCreateUserProfile);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<UploadAvatar>(_onUploadAvatar);
    
    // Document Management
    on<UploadDocument>(_onUploadDocument);
    on<GetUserDocuments>(_onGetUserDocuments);
    on<DeleteDocument>(_onDeleteDocument);
    
    // Badge and Verification Status
    on<GetUserBadges>(_onGetUserBadges);
    on<GetVerificationStatus>(_onGetVerificationStatus);
    
    // Utility Events
    on<ResetProfileState>(_onResetProfileState);
    on<ClearProfileError>(_onClearProfileError);
    on<RefreshProfile>(_onRefreshProfile);
    on<RefreshAllProfileData>(_onRefreshAllProfileData);
  }

  // Profile Management Handlers
  Future<void> _onGetUserProfile(GetUserProfile event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileLoading());
      
      final profile = await _profileService.getUserProfile();
      
      if (profile != null) {
        emit(ProfileLoaded(
          profile: profile,
          documents: profile.verificationStatus.documentsCount > 0 ? await _profileService.getUserDocuments() : [],
          badges: profile.badges,
          verificationStatus: profile.verificationStatus,
        ));
      } else {
        emit(const NoProfile());
      }
    } catch (error) {
      emit(ProfileError(
        message: 'Erreur lors de la récupération du profil',
        error: error,
      ));
    }
  }

  Future<void> _onCreateUserProfile(CreateUserProfile event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileActionLoading(action: 'create'));
      
      // Validate profile data
      final validationError = _profileService.validateProfileData(event.profileData);
      if (validationError != null) {
        emit(ProfileActionError(
          message: validationError,
          action: 'create',
          errorCode: 'VALIDATION_ERROR',
        ));
        return;
      }
      
      final profile = await _profileService.createUserProfile(event.profileData);
      
      emit(ProfileCreated(profile: profile));
      
      // Automatically load all profile data after creation
      add(const GetUserProfile());
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors de la création du profil',
        action: 'create',
        error: error,
      ));
    }
  }

  Future<void> _onUpdateUserProfile(UpdateUserProfile event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileActionLoading(action: 'update'));
      
      // Validate profile data
      final validationError = _profileService.validateProfileData(event.profileData);
      if (validationError != null) {
        emit(ProfileActionError(
          message: validationError,
          action: 'update',
          errorCode: 'VALIDATION_ERROR',
        ));
        return;
      }
      
      final profile = await _profileService.updateUserProfile(event.profileData);
      
      emit(ProfileUpdated(profile: profile));
      
      // Refresh profile data
      add(const GetUserProfile());
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors de la mise à jour du profil',
        action: 'update',
        error: error,
      ));
    }
  }

  Future<void> _onUploadAvatar(UploadAvatar event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileActionLoading(action: 'upload_avatar'));
      
      final uploadResult = await _profileService.uploadAvatar(event.imageFile);
      final avatarUrl = uploadResult['profile_picture'] as String? ?? '';
      
      emit(AvatarUploaded(avatarUrl: avatarUrl));
      
      // Refresh profile to get updated avatar
      add(const GetUserProfile());
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors du téléchargement de l\'avatar',
        action: 'upload_avatar',
        error: error,
      ));
    }
  }

  // Document Management Handlers
  Future<void> _onUploadDocument(UploadDocument event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileActionLoading(action: 'upload_document'));
      
      final document = await _profileService.uploadDocument(
        documentFile: event.documentFile,
        documentType: event.documentType,
        documentNumber: event.documentNumber,
        expiryDate: event.expiryDate,
      );
      
      emit(DocumentUploaded(document: document));
      
      // Refresh profile data to update verification status
      add(const RefreshAllProfileData());
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors du téléchargement du document',
        action: 'upload_document',
        error: error,
      ));
    }
  }

  Future<void> _onGetUserDocuments(GetUserDocuments event, Emitter<ProfileState> emit) async {
    try {

      final documents = await _profileService.getUserDocuments();
      
      emit(DocumentsLoaded(documents: documents));
      
      // Update current state if it's ProfileLoaded
      if (state is ProfileLoaded) {
        final currentState = state as ProfileLoaded;
        emit(currentState.copyWith(documents: documents));
      }
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors de la récupération des documents',
        action: 'get_documents',
        error: error,
      ));
    }
  }

  Future<void> _onDeleteDocument(DeleteDocument event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileActionLoading(action: 'delete_document'));
      
      final success = await _profileService.deleteDocument(event.documentId);
      
      if (success) {
        emit(DocumentDeleted(documentId: event.documentId));
        
        // Refresh documents and verification status
        add(const RefreshAllProfileData());
      } else {
        emit(const ProfileActionError(
          message: 'Impossible de supprimer le document',
          action: 'delete_document',
          errorCode: 'DELETE_FAILED',
        ));
      }
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors de la suppression du document',
        action: 'delete_document',
        error: error,
      ));
    }
  }

  // Badge and Verification Handlers
  Future<void> _onGetUserBadges(GetUserBadges event, Emitter<ProfileState> emit) async {
    try {

      final badges = await _profileService.getUserBadges();
      
      emit(BadgesLoaded(badges: badges));
      
      // Update current state if it's ProfileLoaded
      if (state is ProfileLoaded) {
        final currentState = state as ProfileLoaded;
        emit(currentState.copyWith(badges: badges));
      }
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors de la récupération des badges',
        action: 'get_badges',
        error: error,
      ));
    }
  }

  Future<void> _onGetVerificationStatus(GetVerificationStatus event, Emitter<ProfileState> emit) async {
    try {

      final verificationStatus = await _profileService.getVerificationStatus();
      
      emit(VerificationStatusLoaded(verificationStatus: verificationStatus));
      
      // Update current state if it's ProfileLoaded
      if (state is ProfileLoaded) {
        final currentState = state as ProfileLoaded;
        emit(currentState.copyWith(verificationStatus: verificationStatus));
      }
    } catch (error) {
      emit(ProfileActionError(
        message: 'Erreur lors de la récupération du statut de vérification',
        action: 'get_verification_status',
        error: error,
      ));
    }
  }

  // Utility Handlers
  Future<void> _onResetProfileState(ResetProfileState event, Emitter<ProfileState> emit) async {
    emit(const ProfileInitial());
  }

  Future<void> _onClearProfileError(ClearProfileError event, Emitter<ProfileState> emit) async {
    if (state is ProfileError || state is ProfileActionError) {
      emit(const ProfileInitial());
    }
  }

  Future<void> _onRefreshProfile(RefreshProfile event, Emitter<ProfileState> emit) async {
    add(const GetUserProfile());
  }

  Future<void> _onRefreshAllProfileData(RefreshAllProfileData event, Emitter<ProfileState> emit) async {
    try {

      emit(const ProfileLoading());
      
      // Load all data concurrently
      final futures = await Future.wait([
        _profileService.getUserProfile(),
        _profileService.getUserDocuments(),
        _profileService.getUserBadges(),
        _profileService.getVerificationStatus(),
      ]);
      
      final profile = futures[0] as UserProfile?;
      final documents = futures[1] as List<VerificationDocument>;
      final badges = futures[2] as List<TrustBadge>;
      final verificationStatus = futures[3] as VerificationStatus;
      
      if (profile != null) {
        emit(ProfileLoaded(
          profile: profile,
          documents: documents,
          badges: badges,
          verificationStatus: verificationStatus,
        ));
      } else {
        emit(const NoProfile());
      }
    } catch (error) {
      
      // Try to load partial data
      List<String> errors = [];
      UserProfile? profile;
      List<VerificationDocument>? documents;
      List<TrustBadge>? badges;
      VerificationStatus? verificationStatus;
      
      try {
        profile = await _profileService.getUserProfile();
      } catch (e) {
        errors.add('Profil: ${e.toString()}');
      }
      
      try {
        documents = await _profileService.getUserDocuments();
      } catch (e) {
        errors.add('Documents: ${e.toString()}');
      }
      
      try {
        badges = await _profileService.getUserBadges();
      } catch (e) {
        errors.add('Badges: ${e.toString()}');
      }
      
      try {
        verificationStatus = await _profileService.getVerificationStatus();
      } catch (e) {
        errors.add('Statut de vérification: ${e.toString()}');
      }
      
      if (profile != null || documents != null || badges != null || verificationStatus != null) {
        emit(ProfilePartiallyLoaded(
          profile: profile,
          documents: documents,
          badges: badges,
          verificationStatus: verificationStatus,
          errors: errors,
        ));
      } else {
        emit(ProfileError(
          message: 'Impossible de charger les données du profil',
          error: error,
        ));
      }
    }
  }
}