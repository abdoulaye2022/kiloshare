import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/app_config.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final Dio _dio;

  ProfileService({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl, // Déjà configuré avec http://127.0.0.1:8080/api/v1
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));


    return dio;
  }

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<Options> _getAuthHeaders() async {
    final token = await _getAccessToken();
    return Options(
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  // Profile Management
  Future<UserProfile?> getUserProfile() async {
    try {

      final response = await _dio.get('/user/profile', options: await _getAuthHeaders());


      if (response.data['success'] == true && response.data['data'] != null) {
        // L'API renvoie les données utilisateur dans data.user
        final userData = response.data['data']['user'];
        if (userData != null) {
          // Debug: afficher les données reçues de l'API
          debugPrint('👤 ProfileService - User data: $userData');
          debugPrint('📷 ProfileService - Profile picture: ${userData['profile_picture']}');
          
          // Adapter toutes les données utilisateur au format UserProfile
          return UserProfile.fromJson({
            'first_name': userData['first_name'],
            'last_name': userData['last_name'],
            'phone': userData['phone'],
            'email': userData['email'],
            'profile_picture': userData['profile_picture'],
            'is_verified': userData['is_verified'],
            'gender': userData['gender'],
            'date_of_birth': userData['date_of_birth'],
            'nationality': userData['nationality'],
            'bio': userData['bio'],
            'profession': userData['profession'],
            'company': userData['company'],
            'website': userData['website'],
            'address': userData['address_line1'] ?? userData['address_line2'] ?? '', // Compatibilité legacy
            'address_line1': userData['address_line1'],
            'address_line2': userData['address_line2'],
            'city': userData['city'],
            'state_province': userData['state_province'],
            'postal_code': userData['postal_code'],
            'country': userData['country'],
            'preferred_language': userData['preferred_language'],
            'timezone': userData['timezone'],
            'emergency_contact_name': userData['emergency_contact_name'],
            'emergency_contact_phone': userData['emergency_contact_phone'],
            'emergency_contact_relation': userData['emergency_contact_relation'],
            'profile_visibility': userData['profile_visibility'],
            'newsletter_subscribed': userData['newsletter_subscribed'],
            'marketing_emails': userData['marketing_emails'],
          });
        }
      }

      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Profil non trouvé - c'est normal pour un nouvel utilisateur
        return null;
      }
      
      rethrow;
    }
  }

  Future<UserProfile> createUserProfile(Map<String, dynamic> profileData) async {
    try {

      final response = await _dio.put('/user/profile', data: profileData, options: await _getAuthHeaders());


      if (response.data['success'] == true && response.data['data'] != null) {
        return UserProfile.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de la création du profil');
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile> updateUserProfile(Map<String, dynamic> profileData) async {
    try {

      final response = await _dio.put('/user/profile', data: profileData, options: await _getAuthHeaders());


      if (response.data['success'] == true && response.data['data'] != null) {
        return UserProfile.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de la mise à jour du profil');
    } catch (e) {
      rethrow;
    }
  }

  // Avatar Upload avec Cloudinary
  Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      FormData formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _dio.post(
        '/user/profile/picture', 
        data: formData, 
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final data = response.data['data']['user'] ?? response.data['data'];
        return {
          'profile_picture': data['profile_picture'],
          'profile_picture_thumbnail': data['profile_picture_thumbnail'],
          'message': response.data['message'] ?? 'Avatar uploaded successfully',
        };
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de l\'upload de l\'avatar vers Cloudinary');
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Network error';
        throw Exception('Upload failed: $errorMessage');
      }
      rethrow;
    }
  }

  // ENDPOINT NON DISPONIBLE - Upload de documents non supporté
  Future<VerificationDocument> uploadDocument({
    required File documentFile,
    required String documentType,
    String? documentNumber,
    DateTime? expiryDate,
  }) async {
    throw Exception('Upload de documents non supporté pour le moment');
  }

  // ENDPOINT NON DISPONIBLE - Documents non supportés pour le moment
  Future<List<VerificationDocument>> getUserDocuments() async {
    return [];
  }

  // ENDPOINT NON DISPONIBLE - Suppression documents non supportée
  Future<bool> deleteDocument(int documentId) async {
    return false;
  }

  // Trust Badges
  // ENDPOINT NON DISPONIBLE - Badges non supportés pour le moment
  Future<List<TrustBadge>> getUserBadges() async {
    return [];
  }

  // Verification Status
  // ENDPOINT NON DISPONIBLE - Statut de vérification non supporté
  Future<VerificationStatus> getVerificationStatus() async {
    return const VerificationStatus();
  }

  // Helper Methods
  Future<bool> hasProfile() async {
    try {
      final profile = await getUserProfile();
      return profile != null;
    } catch (e) {
      return false;
    }
  }

  List<String> getAvailableDocumentTypes() {
    return [
      'identity_card',
      'passport', 
      'driver_license',
      'proof_of_address',
      'bank_statement',
      'utility_bill',
      'selfie_with_id'
    ];
  }

  String getDocumentTypeDisplayName(String documentType) {
    switch (documentType) {
      case 'identity_card':
        return 'Carte d\'identité';
      case 'passport':
        return 'Passeport';
      case 'driver_license':
        return 'Permis de conduire';
      case 'proof_of_address':
        return 'Justificatif de domicile';
      case 'bank_statement':
        return 'Relevé bancaire';
      case 'utility_bill':
        return 'Facture d\'utilité';
      case 'selfie_with_id':
        return 'Selfie avec pièce d\'identité';
      default:
        return documentType;
    }
  }

  List<String> getAvailableGenders() {
    return ['', 'male', 'female', 'other'];
  }

  String getGenderDisplayName(String gender) {
    switch (gender) {
      case '':
        return 'Non spécifié';
      case 'male':
        return 'Homme';
      case 'female':
        return 'Femme';
      case 'other':
        return 'Autre';
      default:
        return gender;
    }
  }

  List<String> getAvailableCountries() {
    return [
      '', // Option vide pour "Non spécifié"
      'France',
      'Belgique',
      'Suisse',
      'Canada',
      'Maroc',
      'Algérie',
      'Tunisie',
      'Sénégal',
      'Côte d\'Ivoire',
      'Cameroun',
      'Mali',
      'Burkina Faso',
      'Niger',
      'Madagascar',
      'Maurice',
      'Réunion',
      'Guadeloupe',
      'Martinique',
      'Guyane',
    ];
  }

  // Validation helpers
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)\.]{8,}$').hasMatch(phone);
  }

  bool isValidWebsite(String website) {
    return RegExp(r'^https?:\/\/.+\..+').hasMatch(website);
  }

  String? validateProfileData(Map<String, dynamic> data) {
    // Validation du prénom
    if (data['first_name'] != null && data['first_name'].toString().trim().isEmpty) {
      return 'Le prénom ne peut pas être vide';
    }

    // Validation du nom
    if (data['last_name'] != null && data['last_name'].toString().trim().isEmpty) {
      return 'Le nom ne peut pas être vide';
    }

    // Validation du téléphone
    if (data['phone'] != null && !isValidPhone(data['phone'])) {
      return 'Le numéro de téléphone n\'est pas valide';
    }

    // Validation du site web
    if (data['website'] != null && data['website'].toString().trim().isNotEmpty && !isValidWebsite(data['website'])) {
      return 'L\'URL du site web n\'est pas valide';
    }

    // Validation de la date de naissance
    if (data['date_of_birth'] != null) {
      try {
        DateTime birthDate = DateTime.parse(data['date_of_birth']);
        DateTime now = DateTime.now();
        int age = now.year - birthDate.year;
        if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
          age--;
        }
        if (age < 13) {
          return 'L\'âge minimum requis est de 13 ans';
        }
        if (age > 120) {
          return 'Veuillez vérifier votre date de naissance';
        }
      } catch (e) {
        return 'Format de date de naissance invalide';
      }
    }

    return null; // Aucune erreur
  }
}