import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/delivery_code_model.dart';

class DeliveryCodeService {
  static final DeliveryCodeService _instance = DeliveryCodeService._internal();
  factory DeliveryCodeService() => _instance;
  DeliveryCodeService._internal();

  static DeliveryCodeService get instance => _instance;

  final String _baseUrl = AppConfig.baseUrl;
  final AuthService _authService = AuthService.instance;

  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      print('DeliveryCodeService: No valid token found');
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Génère un code de livraison pour une réservation (transporteur uniquement)
  Future<Map<String, dynamic>> generateDeliveryCode(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/generate'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'delivery_code': DeliveryCodeModel.fromJson(responseData['data']['delivery_code']),
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la génération du code',
        };
      }
    } catch (e) {
      print('Erreur DeliveryCodeService.generateDeliveryCode: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Valide un code de livraison avec géolocalisation et photos
  Future<Map<String, dynamic>> validateDeliveryCode({
    required String bookingId,
    required String code,
    List<File>? photos,
    bool requireLocation = true,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      // Obtenir la géolocalisation si requise
      Position? position;
      if (requireLocation) {
        final locationResult = await _getCurrentLocation();
        if (!locationResult['success']) {
          return {
            'success': false,
            'error': locationResult['error'],
          };
        }
        position = locationResult['position'];
      }

      // Convertir les photos en base64 si fournies
      List<String> photoStrings = [];
      if (photos != null && photos.isNotEmpty) {
        for (File photo in photos) {
          try {
            final bytes = await photo.readAsBytes();
            final base64String = base64Encode(bytes);
            photoStrings.add('data:image/jpeg;base64,$base64String');
          } catch (e) {
            print('Erreur lors de la conversion de photo: $e');
          }
        }
      }

      // Préparer les données
      final requestData = {
        'code': code,
        if (position != null) ...{
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        if (photoStrings.isNotEmpty) 'photos': photoStrings,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/validate'),
        headers: headers,
        body: json.encode(requestData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'booking_status': responseData['data']['booking_status'],
          'delivery_confirmed_at': responseData['data']['delivery_confirmed_at'],
          'photos_uploaded': responseData['data']['photos_uploaded'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Code incorrect',
          'attempts_remaining': responseData['data']?['attempts_remaining'] ?? 0,
        };
      }
    } catch (e) {
      print('Erreur DeliveryCodeService.validateDeliveryCode: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Régénère un code de livraison (expéditeur uniquement)
  Future<Map<String, dynamic>> regenerateDeliveryCode({
    required String bookingId,
    String? reason,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      final requestData = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        requestData['reason'] = reason;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/regenerate'),
        headers: headers,
        body: json.encode(requestData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'delivery_code': DeliveryCodeModel.fromJson(responseData['data']['delivery_code']),
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la régénération du code',
        };
      }
    } catch (e) {
      print('Erreur DeliveryCodeService.regenerateDeliveryCode: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Récupère les informations du code de livraison
  Future<Map<String, dynamic>> getDeliveryCode(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'delivery_code': DeliveryCodeModel.fromJson(responseData['data']['delivery_code']),
          'booking': responseData['data']['booking'],
          'is_sender': responseData['data']['is_sender'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Code de livraison non trouvé',
        };
      }
    } catch (e) {
      print('Erreur DeliveryCodeService.getDeliveryCode: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Vérifie si un code de livraison est requis
  Future<Map<String, dynamic>> checkDeliveryCodeRequired(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/required'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'required': responseData['data']['required'],
          'has_active_code': responseData['data']['has_active_code'],
          'booking_status': responseData['data']['booking_status'],
          'delivery_confirmed': responseData['data']['delivery_confirmed'],
          'trip': responseData['data']['trip'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la vérification',
        };
      }
    } catch (e) {
      print('Erreur DeliveryCodeService.checkDeliveryCodeRequired: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Récupère l'historique des tentatives
  Future<Map<String, dynamic>> getDeliveryCodeAttempts(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {
          'success': false,
          'error': 'Utilisateur non connecté',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/bookings/$bookingId/delivery-code/attempts'),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'attempts': responseData['data']['attempts'],
          'total_attempts': responseData['data']['total_attempts'],
          'successful_attempts': responseData['data']['successful_attempts'],
          'remaining_attempts': responseData['data']['remaining_attempts'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Erreur lors de la récupération des tentatives',
        };
      }
    } catch (e) {
      print('Erreur DeliveryCodeService.getDeliveryCodeAttempts: $e');
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  /// Obtient la géolocalisation actuelle
  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      // Vérifier les permissions de géolocalisation
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'success': false,
            'error': 'Permissions de géolocalisation refusées',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'error': 'Permissions de géolocalisation refusées de manière permanente',
        };
      }

      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'success': false,
          'error': 'Service de géolocalisation désactivé',
        };
      }

      // Obtenir la position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'success': true,
        'position': position,
      };
    } catch (e) {
      print('Erreur géolocalisation: $e');
      return {
        'success': false,
        'error': 'Erreur lors de l\'obtention de la géolocalisation: $e',
      };
    }
  }

  /// Prend une photo avec l'appareil photo
  Future<File?> takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la prise de photo: $e');
      return null;
    }
  }

  /// Sélectionne des photos depuis la galerie
  Future<List<File>> pickPhotosFromGallery({int maxPhotos = 3}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      // Limiter le nombre de photos
      final limitedImages = images.take(maxPhotos).toList();

      return limitedImages.map((image) => File(image.path)).toList();
    } catch (e) {
      print('Erreur lors de la sélection de photos: $e');
      return [];
    }
  }

  /// Vérifier les permissions géolocalisation et appareil photo
  Future<Map<String, bool>> checkPermissions() async {
    try {
      // Vérifier géolocalisation
      LocationPermission locationPermission = await Geolocator.checkPermission();
      bool hasLocationPermission = locationPermission == LocationPermission.always ||
                                  locationPermission == LocationPermission.whileInUse;

      // Pour l'appareil photo, on suppose qu'on peut demander la permission au moment de l'usage
      return {
        'location': hasLocationPermission,
        'camera': true, // ImagePicker gère les permissions automatiquement
      };
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      return {
        'location': false,
        'camera': false,
      };
    }
  }
}