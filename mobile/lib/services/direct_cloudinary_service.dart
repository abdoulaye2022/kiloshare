import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../config/environment.dart';

/// Service pour upload direct vers Cloudinary (sans passer par notre API)
class DirectCloudinaryService {
  final Dio _dio;
  
  // Configuration Cloudinary depuis les variables d'environnement
  static String get cloudinaryUrl => Environment.cloudinaryUploadUrl;
  static String get cloudName => Environment.cloudinaryCloudName;
  static String get apiKey => Environment.cloudinaryApiKey;
  static String get apiSecret => Environment.cloudinaryApiSecret;
  
  DirectCloudinaryService({Dio? dio}) : _dio = dio ?? Dio();

  /// Upload multiple photos de voyage directement vers Cloudinary
  Future<List<Map<String, dynamic>>> uploadTripPhotos(
    List<File> imageFiles, {
    Function(double)? onProgress,
  }) async {
    try {
      if (imageFiles.length > 5) {
        throw Exception('Maximum 5 photos par voyage');
      }

      final results = <Map<String, dynamic>>[];
      
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        
        // Compresser l'image
        final compressedFile = await _compressImage(file);
        
        // Créer les paramètres pour l'upload signé
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final publicId = 'trip_${timestamp}_$i';  // Sans le folder, car il sera ajouté automatiquement
        
        // Paramètres pour la signature
        final params = {
          'folder': 'kiloshare/trips',
          'public_id': publicId,
          'timestamp': timestamp,
        };
        
        // Créer la signature
        final signature = _generateSignature(params, apiSecret);
        
        // Créer FormData pour Cloudinary
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            compressedFile.path,
            filename: 'trip_${timestamp}_$i.jpg',
          ),
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
          'folder': 'kiloshare/trips',
          'public_id': publicId,
        });

        
        // Upload vers Cloudinary
        final response = await _dio.post(
          cloudinaryUrl,
          data: formData,
          onSendProgress: onProgress != null 
            ? (sent, total) => onProgress((i + sent/total) / imageFiles.length)
            : null,
        );

        // Nettoyer le fichier temporaire
        await _cleanupTempFile(compressedFile);


        if (response.statusCode == 200) {
          final data = response.data;
          
          // Check if upload was successful
          if (data['secure_url'] != null) {
            results.add({
              'url': data['secure_url'],
              'public_id': data['public_id'],
              'thumbnail': data['secure_url'].replaceAll('/upload/', '/upload/c_fill,w_300,h_200,q_auto:good/'),
              'width': data['width'],
              'height': data['height'],
              'file_size': data['bytes'],
              'format': data['format'],
              'is_primary': i == 0,
              'alt_text': null,
              'order': i,
            });
          } else {
            throw Exception('Upload failed for image $i: No secure_url in response');
          }
        } else {
          throw Exception('Upload failed for image $i: ${response.statusCode} - ${response.data}');
        }
      }

      return results;
      
    } catch (e) {
      rethrow;
    }
  }

  /// Compresser une image
  Future<File> _compressImage(File imageFile) async {
    final String targetPath = path.join(
      path.dirname(imageFile.path),
      '${path.basenameWithoutExtension(imageFile.path)}_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg'
    );

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 75,
      minWidth: 800,
      minHeight: 600,
      format: CompressFormat.jpeg,
    );

    if (compressedFile == null) {
      throw Exception('Échec de la compression d\'image');
    }

    return File(compressedFile.path);
  }

  /// Nettoyer un fichier temporaire
  Future<void> _cleanupTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Générer une signature pour l'upload Cloudinary
  String _generateSignature(Map<String, String> params, String apiSecret) {
    // Trier les paramètres par clé
    final sortedKeys = params.keys.toList()..sort();
    
    // Construire la chaîne de signature
    final signatureString = sortedKeys
        .map((key) => '$key=${params[key]}')
        .join('&') + apiSecret;
    
    // Générer le hash SHA-1
    final bytes = utf8.encode(signatureString);
    final digest = sha1.convert(bytes);
    
    return digest.toString();
  }
}