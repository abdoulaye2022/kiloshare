import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service pour uploader les images via l'API backend qui gère Google Cloud Storage
class GCSImageService {
  final String baseUrl;

  GCSImageService({String? apiUrl})
    : baseUrl = apiUrl ?? dotenv.env['API_URL'] ?? 'http://127.0.0.1:8080/api/v1';

  /// Upload une image de trip via l'API
  Future<Map<String, dynamic>> uploadTripImage({
    required File imageFile,
    required int tripId,
    required String authToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/trips/$tripId/images');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $authToken';

      // Ajouter le fichier
      request.files.add(
        await http.MultipartFile.fromPath(
          'images[]',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Upload failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Upload un avatar via l'API
  Future<Map<String, dynamic>> uploadAvatar({
    required File imageFile,
    required String authToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/user/profile/avatar');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $authToken';

      // Ajouter le fichier
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Upload failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Supprimer une image de trip
  Future<Map<String, dynamic>> deleteTripImage({
    required int tripId,
    required int imageId,
    required String authToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/trips/$tripId/images/$imageId');

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Image deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Delete failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Obtenir l'URL publique d'une image GCS
  /// Les images GCS sont déjà accessibles publiquement
  String getPublicUrl(String path) {
    final bucketName = dotenv.env['GCS_BUCKET_NAME'] ?? 'kiloshare';
    return 'https://storage.googleapis.com/$bucketName/$path';
  }

  /// Obtenir une URL optimisée (pour GCS, c'est la même que l'URL publique)
  /// Note: Pour l'optimisation, vous pourriez utiliser Cloud CDN ou Images API
  String getOptimizedUrl(String path, {int? width, int? height, String? format}) {
    // GCS ne fournit pas d'optimisation automatique comme Cloudinary
    // Vous devrez soit :
    // 1. Utiliser Cloud CDN
    // 2. Utiliser Cloud Functions pour redimensionner
    // 3. Pré-générer plusieurs tailles lors de l'upload
    return getPublicUrl(path);
  }

  /// Obtenir une URL de thumbnail
  /// Note: Contrairement à Cloudinary, GCS ne génère pas automatiquement de thumbnails
  /// Vous devrez les générer lors de l'upload côté backend
  String getThumbnailUrl(String path) {
    // Option 1: Retourner l'image originale
    // Option 2: Si vous avez un système de thumbnails, construire le chemin
    // Par exemple: remplacer 'images/' par 'thumbnails/'
    if (path.startsWith('trips/')) {
      return getPublicUrl(path.replaceFirst('trips/', 'thumbnails/trips/'));
    }
    return getPublicUrl(path);
  }
}
