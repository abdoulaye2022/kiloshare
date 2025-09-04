import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

/// Service pour upload direct vers Cloudinary (sans passer par notre API)
class DirectCloudinaryService {
  final Dio _dio;
  
  // Configuration Cloudinary - À REMPLACER par vos vraies clés
  static const String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/YOUR_CLOUD_NAME/image/upload';
  static const String uploadPreset = 'YOUR_UPLOAD_PRESET'; // Preset unsigned
  
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
        
        // Créer FormData pour Cloudinary
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            compressedFile.path,
            filename: 'trip_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ),
          'upload_preset': uploadPreset,
          'folder': 'kiloshare/trips',
          'resource_type': 'image',
          'transformation': 'c_fill,w_800,h_600,q_auto:good',
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
          throw Exception('Upload failed for image $i: ${response.statusCode}');
        }
      }

      return results;
      
    } catch (e) {
      print('DirectCloudinaryService error: $e');
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
}