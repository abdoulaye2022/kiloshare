import 'dart:io';
import 'dart:convert';
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
      baseUrl: '${AppConfig.baseUrl}/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print(obj),
      ));
    }

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
      if (kDebugMode) {
        print('[ProfileService] Récupération du profil utilisateur');
      }

      final response = await _dio.get('/profile', options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse du serveur: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserProfile.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Profil non trouvé - c'est normal pour un nouvel utilisateur
        if (kDebugMode) {
          print('[ProfileService] Profil non trouvé - utilisateur sans profil');
        }
        return null;
      }
      
      if (kDebugMode) {
        print('[ProfileService] Erreur lors de la récupération du profil: $e');
      }
      rethrow;
    }
  }

  Future<UserProfile> createUserProfile(Map<String, dynamic> profileData) async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Création du profil: $profileData');
      }

      final response = await _dio.post('/profile', data: profileData, options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse création profil: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserProfile.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de la création du profil');
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur création profil: $e');
      }
      rethrow;
    }
  }

  Future<UserProfile> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Mise à jour du profil: $profileData');
      }

      final response = await _dio.put('/profile', data: profileData, options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse mise à jour profil: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return UserProfile.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de la mise à jour du profil');
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur mise à jour profil: $e');
      }
      rethrow;
    }
  }

  // Avatar Upload avec Cloudinary
  Future<String> uploadAvatar(File imageFile) async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Upload avatar vers Cloudinary: ${imageFile.path}');
      }

      FormData formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _dio.post('/images/avatar', data: formData, options: Options(
        headers: {
          if (await _getAccessToken() != null) 'Authorization': 'Bearer ${await _getAccessToken()}',
        },
      ));

      if (kDebugMode) {
        print('[ProfileService] Réponse upload avatar Cloudinary: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data']['avatar_url'] ?? 
               response.data['data']['cloudinary_url'] ?? 
               response.data['data']['secure_url'] ?? '';
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de l\'upload de l\'avatar vers Cloudinary');
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur upload avatar Cloudinary: $e');
      }
      rethrow;
    }
  }

  // Document Verification
  Future<VerificationDocument> uploadDocument({
    required File documentFile,
    required String documentType,
    String? documentNumber,
    DateTime? expiryDate,
  }) async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Upload document: $documentType, ${documentFile.path}');
      }

      FormData formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          documentFile.path,
          filename: 'document_${DateTime.now().millisecondsSinceEpoch}.${documentFile.path.split('.').last}',
        ),
        'document_type': documentType,
        if (documentNumber != null) 'document_number': documentNumber,
        if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String().split('T')[0],
      });

      final response = await _dio.post('/profile/documents', data: formData, options: Options(
        headers: {
          if (await _getAccessToken() != null) 'Authorization': 'Bearer ${await _getAccessToken()}',
        },
      ));

      if (kDebugMode) {
        print('[ProfileService] Réponse upload document: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return VerificationDocument.fromJson(response.data['data']);
      }

      throw Exception(response.data['message'] ?? 'Erreur lors de l\'upload du document');
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur upload document: $e');
      }
      rethrow;
    }
  }

  Future<List<VerificationDocument>> getUserDocuments() async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Récupération des documents utilisateur');
      }

      final response = await _dio.get('/profile/documents', options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse documents: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        List<dynamic> documentsJson = response.data['data'];
        return documentsJson.map((doc) => VerificationDocument.fromJson(doc)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur récupération documents: $e');
      }
      rethrow;
    }
  }

  Future<bool> deleteDocument(int documentId) async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Suppression document: $documentId');
      }

      final response = await _dio.delete('/profile/documents/$documentId', options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse suppression document: ${response.data}');
      }

      return response.data['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur suppression document: $e');
      }
      rethrow;
    }
  }

  // Trust Badges
  Future<List<TrustBadge>> getUserBadges() async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Récupération des badges utilisateur');
      }

      final response = await _dio.get('/profile/badges', options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse badges: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        List<dynamic> badgesJson = response.data['data'];
        return badgesJson.map((badge) => TrustBadge.fromJson(badge)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur récupération badges: $e');
      }
      rethrow;
    }
  }

  // Verification Status
  Future<VerificationStatus> getVerificationStatus() async {
    try {
      if (kDebugMode) {
        print('[ProfileService] Récupération du statut de vérification');
      }

      final response = await _dio.get('/profile/verification-status', options: await _getAuthHeaders());

      if (kDebugMode) {
        print('[ProfileService] Réponse statut vérification: ${response.data}');
      }

      if (response.data['success'] == true && response.data['data'] != null) {
        return VerificationStatus.fromJson(response.data['data']);
      }

      return const VerificationStatus();
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileService] Erreur récupération statut vérification: $e');
      }
      rethrow;
    }
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
    return ['male', 'female', 'other'];
  }

  String getGenderDisplayName(String gender) {
    switch (gender) {
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