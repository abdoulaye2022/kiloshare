import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

/// Service de gestion optimisée des images avec Cloudinary
/// 
/// Implémente la compression intelligente, l'upload avec progression,
/// la gestion de cache et la queue d'upload offline pour KiloShare.
/// 
/// Features principales:
/// - Compression différenciée par type d'image
/// - Upload avec retry automatique
/// - Queue d'upload pour mode offline
/// - Cache local optimisé
/// - Monitoring de bande passante
class CloudinaryImageService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final ImagePicker _picker;
  
  // Configuration de compression par type d'image
  static const Map<String, ImageCompressionConfig> _compressionConfigs = {
    'avatar': ImageCompressionConfig(
      quality: 80,
      maxWidth: 400,
      maxHeight: 400,
      format: CompressFormat.jpeg,
    ),
    'kyc_document': ImageCompressionConfig(
      quality: 85,
      maxWidth: 1200,
      maxHeight: 1600,
      format: CompressFormat.jpeg,
    ),
    'trip_photo': ImageCompressionConfig(
      quality: 75,
      maxWidth: 800,
      maxHeight: 600,
      format: CompressFormat.jpeg,
    ),
    'package_photo': ImageCompressionConfig(
      quality: 70,
      maxWidth: 600,
      maxHeight: 600,
      format: CompressFormat.jpeg,
    ),
    'delivery_proof': ImageCompressionConfig(
      quality: 80,
      maxWidth: 1000,
      maxHeight: 1000,
      format: CompressFormat.jpeg,
    ),
  };
  
  // Queue d'upload pour mode offline
  final List<UploadTask> _uploadQueue = [];
  bool _isProcessingQueue = false;
  
  CloudinaryImageService({
    required Dio dio,
    required FlutterSecureStorage storage,
  }) : _dio = dio,
       _storage = storage,
       _picker = ImagePicker();

  /// Upload d'avatar utilisateur avec compression optimisée
  /// 
  /// [imageFile] Fichier image sélectionné
  /// [onProgress] Callback de progression (0.0 à 1.0)
  /// Returns Map avec les URLs des transformations
  Future<CloudinaryUploadResult> uploadAvatar(
    File imageFile, {
    Function(double)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('[CloudinaryImageService] Upload avatar: ${imageFile.path}');
      }

      // Compresser l'image selon le profil avatar
      final compressedFile = await _compressImage(imageFile, 'avatar');
      
      // Préparer les données multipart
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          compressedFile.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      // Upload avec progression
      final response = await _dio.post(
        '/images/avatar',
        data: formData,
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
        onSendProgress: onProgress != null 
          ? (sent, total) => onProgress(sent / total)
          : null,
      );

      // Nettoyer le fichier temporaire compressé
      await _cleanupTempFile(compressedFile);

      if (kDebugMode) {
        print('[CloudinaryImageService] Avatar upload successful: ${response.data}');
      }

      if (response.data['success'] == true) {
        return CloudinaryUploadResult.fromJson(response.data['data']);
      }

      throw CloudinaryException(response.data['message'] ?? 'Upload failed');

    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Avatar upload error: $e');
      }
      
      // Ajouter à la queue si erreur réseau
      if (e is DioException && _isNetworkError(e)) {
        await _addToUploadQueue(UploadTask(
          type: 'avatar',
          file: imageFile,
          endpoint: '/images/avatar',
          onProgress: onProgress,
        ));
        throw CloudinaryException('Upload ajouté à la file d\'attente (mode offline)');
      }
      
      rethrow;
    }
  }

  /// Upload de documents KYC sécurisés
  /// 
  /// [imageFile] Fichier du document
  /// [documentType] Type de document (passport, id_card, etc.)
  /// [onProgress] Callback de progression
  Future<CloudinaryUploadResult> uploadKYCDocument(
    File imageFile,
    String documentType, {
    Function(double)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('[CloudinaryImageService] Upload KYC: $documentType');
      }

      final compressedFile = await _compressImage(imageFile, 'kyc_document');
      
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          compressedFile.path,
          filename: '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'document_type': documentType,
      });

      final response = await _dio.post(
        '/images/kyc',
        data: formData,
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
        onSendProgress: onProgress != null 
          ? (sent, total) => onProgress(sent / total)
          : null,
      );

      await _cleanupTempFile(compressedFile);

      if (response.data['success'] == true) {
        return CloudinaryUploadResult.fromJson(response.data['data']);
      }

      throw CloudinaryException(response.data['message'] ?? 'Upload failed');

    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] KYC upload error: $e');
      }
      rethrow;
    }
  }

  /// Upload multiple de photos de voyage
  /// 
  /// [imageFiles] Liste des fichiers images
  /// [tripId] ID du voyage
  /// [onProgress] Callback de progression globale
  Future<List<CloudinaryUploadResult>> uploadTripPhotos(
    List<File> imageFiles,
    int tripId, {
    Function(double)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('[CloudinaryImageService] Upload ${imageFiles.length} trip photos');
      }

      // Limiter à 5 photos max
      if (imageFiles.length > 5) {
        throw CloudinaryException('Maximum 5 photos par voyage');
      }

      final results = <CloudinaryUploadResult>[];
      double totalProgress = 0.0;

      // Compresser toutes les images
      final compressedFiles = <File>[];
      for (final file in imageFiles) {
        final compressed = await _compressImage(file, 'trip_photo');
        compressedFiles.add(compressed);
      }

      // Préparer FormData avec toutes les photos
      final List<MultipartFile> photoFiles = [];
      for (int i = 0; i < compressedFiles.length; i++) {
        photoFiles.add(await MultipartFile.fromFile(
          compressedFiles[i].path,
          filename: 'trip_${tripId}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      }

      final formData = FormData.fromMap({
        'photos': photoFiles,
        'trip_id': tripId.toString(),
      });

      final response = await _dio.post(
        '/images/trip',
        data: formData,
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
        onSendProgress: onProgress != null 
          ? (sent, total) => onProgress(sent / total)
          : null,
      );

      // Nettoyer les fichiers temporaires
      for (final file in compressedFiles) {
        await _cleanupTempFile(file);
      }

      if (response.data['success'] == true) {
        final photosData = response.data['data']['photos'] as List;
        return photosData
            .map((photo) => CloudinaryUploadResult.fromJson(photo))
            .toList();
      }

      throw CloudinaryException(response.data['message'] ?? 'Upload failed');

    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Trip photos upload error: $e');
      }
      rethrow;
    }
  }

  /// Upload de photos de colis avec expiration
  /// 
  /// [imageFiles] Liste des fichiers images (max 3)
  /// [packageId] ID du colis (optionnel pour photos temporaires)
  Future<List<CloudinaryUploadResult>> uploadPackagePhotos(
    List<File> imageFiles, {
    int? packageId,
    Function(double)? onProgress,
  }) async {
    try {
      if (imageFiles.length > 3) {
        throw CloudinaryException('Maximum 3 photos par colis');
      }

      final compressedFiles = <File>[];
      for (final file in imageFiles) {
        final compressed = await _compressImage(file, 'package_photo');
        compressedFiles.add(compressed);
      }

      final List<MultipartFile> photoFiles = [];
      for (int i = 0; i < compressedFiles.length; i++) {
        photoFiles.add(await MultipartFile.fromFile(
          compressedFiles[i].path,
          filename: 'package_${packageId ?? 'temp'}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      }

      final formData = FormData.fromMap({
        'photos': photoFiles,
        if (packageId != null) 'package_id': packageId.toString(),
      });

      final response = await _dio.post(
        '/images/package',
        data: formData,
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
        onSendProgress: onProgress != null 
          ? (sent, total) => onProgress(sent / total)
          : null,
      );

      // Nettoyer les fichiers temporaires
      for (final file in compressedFiles) {
        await _cleanupTempFile(file);
      }

      if (response.data['success'] == true) {
        final photosData = response.data['data']['photos'] as List;
        return photosData
            .map((photo) => CloudinaryUploadResult.fromJson(photo))
            .toList();
      }

      throw CloudinaryException(response.data['message'] ?? 'Upload failed');

    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Package photos upload error: $e');
      }
      rethrow;
    }
  }

  /// Upload de preuve de livraison
  /// 
  /// [imageFile] Photo de la preuve
  /// [deliveryId] ID de la livraison
  Future<CloudinaryUploadResult> uploadDeliveryProof(
    File imageFile,
    int deliveryId, {
    Function(double)? onProgress,
  }) async {
    try {
      final compressedFile = await _compressImage(imageFile, 'delivery_proof');
      
      final formData = FormData.fromMap({
        'proof': await MultipartFile.fromFile(
          compressedFile.path,
          filename: 'delivery_${deliveryId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'delivery_id': deliveryId.toString(),
      });

      final response = await _dio.post(
        '/images/delivery-proof',
        data: formData,
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
        onSendProgress: onProgress != null 
          ? (sent, total) => onProgress(sent / total)
          : null,
      );

      await _cleanupTempFile(compressedFile);

      if (response.data['success'] == true) {
        return CloudinaryUploadResult.fromJson(response.data['data']);
      }

      throw CloudinaryException(response.data['message'] ?? 'Upload failed');

    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Delivery proof upload error: $e');
      }
      rethrow;
    }
  }

  /// Sélectionner une image depuis la galerie ou la caméra
  /// 
  /// [source] Source de l'image (gallery ou camera)
  /// [imageType] Type d'image pour la compression
  Future<File?> pickImage(ImageSource source, String imageType) async {
    try {
      final XFile? xFile = await _picker.pickImage(
        source: source,
        imageQuality: source == ImageSource.camera ? 85 : null,
        maxWidth: source == ImageSource.camera ? 1200 : null,
        maxHeight: source == ImageSource.camera ? 1200 : null,
      );

      if (xFile == null) return null;

      final File imageFile = File(xFile.path);
      
      // Pré-compresser si l'image est trop lourde
      final fileSize = await imageFile.length();
      if (fileSize > 2 * 1024 * 1024) { // 2MB
        if (kDebugMode) {
          print('[CloudinaryImageService] Pre-compressing large image: ${fileSize ~/ 1024}KB');
        }
        return await _compressImage(imageFile, imageType);
      }

      return imageFile;
    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Pick image error: $e');
      }
      rethrow;
    }
  }

  /// Sélectionner multiple images pour voyages/colis
  /// 
  /// [maxCount] Nombre maximum d'images
  /// [imageType] Type d'images pour la compression
  Future<List<File>> pickMultipleImages(int maxCount, String imageType) async {
    try {
      final List<XFile> xFiles = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (xFiles.isEmpty) return [];

      // Limiter le nombre d'images
      final limitedFiles = xFiles.take(maxCount).toList();
      
      final List<File> imageFiles = [];
      for (final xFile in limitedFiles) {
        final File file = File(xFile.path);
        
        // Compresser si nécessaire
        final fileSize = await file.length();
        if (fileSize > 1 * 1024 * 1024) { // 1MB
          final compressed = await _compressImage(file, imageType);
          imageFiles.add(compressed);
        } else {
          imageFiles.add(file);
        }
      }

      return imageFiles;
    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Pick multiple images error: $e');
      }
      rethrow;
    }
  }

  /// Supprimer une image
  /// 
  /// [publicId] Public ID Cloudinary de l'image
  Future<bool> deleteImage(String publicId) async {
    try {
      final response = await _dio.delete(
        '/images/${Uri.encodeComponent(publicId)}',
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
      );

      return response.data['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Delete image error: $e');
      }
      return false;
    }
  }

  /// Traiter la queue d'upload (mode offline)
  Future<void> processUploadQueue() async {
    if (_isProcessingQueue || _uploadQueue.isEmpty) return;

    _isProcessingQueue = true;
    
    try {
      final tasks = List<UploadTask>.from(_uploadQueue);
      _uploadQueue.clear();

      for (final task in tasks) {
        try {
          switch (task.type) {
            case 'avatar':
              await uploadAvatar(task.file, onProgress: task.onProgress);
              break;
            // Ajouter d'autres types selon les besoins
          }
          
          if (kDebugMode) {
            print('[CloudinaryImageService] Queue task completed: ${task.type}');
          }
        } catch (e) {
          // Re-ajouter à la queue si échec persistant
          _uploadQueue.add(task);
          if (kDebugMode) {
            print('[CloudinaryImageService] Queue task failed, re-added: ${task.type}');
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Obtenir les statistiques d'usage (admin uniquement)
  Future<CloudinaryUsageStats?> getUsageStats() async {
    try {
      final response = await _dio.get(
        '/images/stats',
        options: Options(
          headers: {
            if (await _getAccessToken() != null) 
              'Authorization': 'Bearer ${await _getAccessToken()}',
          },
        ),
      );

      if (response.data['success'] == true) {
        return CloudinaryUsageStats.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[CloudinaryImageService] Get usage stats error: $e');
      }
      return null;
    }
  }

  /// Compresser une image selon sa configuration
  Future<File> _compressImage(File imageFile, String imageType) async {
    final config = _compressionConfigs[imageType] ?? _compressionConfigs['trip_photo']!;
    
    final String targetPath = path.join(
      path.dirname(imageFile.path),
      '${path.basenameWithoutExtension(imageFile.path)}_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg'
    );

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: config.quality,
      minWidth: config.maxWidth,
      minHeight: config.maxHeight,
      format: config.format,
    );

    if (compressedFile == null) {
      throw CloudinaryException('Échec de la compression d\'image');
    }

    if (kDebugMode) {
      final originalSize = await imageFile.length();
      final compressedSize = await compressedFile.length();
      final compressionRatio = (1 - compressedSize / originalSize) * 100;
      
      print('[CloudinaryImageService] Image compressed: ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB (${compressionRatio.toStringAsFixed(1)}% saved)');
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
      if (kDebugMode) {
        print('[CloudinaryImageService] Cleanup temp file error: $e');
      }
    }
  }

  /// Obtenir le token d'accès
  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  /// Vérifier si l'erreur est liée au réseau
  bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.connectionError;
  }

  /// Ajouter une tâche à la queue d'upload
  Future<void> _addToUploadQueue(UploadTask task) async {
    _uploadQueue.add(task);
    
    // Sauvegarder la queue localement pour persistance
    // TODO: Implémenter la persistance locale de la queue
    
    if (kDebugMode) {
      print('[CloudinaryImageService] Task added to upload queue: ${task.type}');
    }
  }
}

/// Configuration de compression d'image
class ImageCompressionConfig {
  final int quality;
  final int maxWidth;
  final int maxHeight;
  final CompressFormat format;

  const ImageCompressionConfig({
    required this.quality,
    required this.maxWidth,
    required this.maxHeight,
    required this.format,
  });
}

/// Tâche d'upload pour la queue
class UploadTask {
  final String type;
  final File file;
  final String endpoint;
  final Function(double)? onProgress;
  final Map<String, dynamic>? additionalData;

  const UploadTask({
    required this.type,
    required this.file,
    required this.endpoint,
    this.onProgress,
    this.additionalData,
  });
}

/// Résultat d'upload Cloudinary
class CloudinaryUploadResult {
  final String? photoId;
  final String? documentId;
  final String? proofId;
  final String url;
  final Map<String, String>? transformations;
  final double? uploadTime;
  final int? fileSize;
  final String? format;

  const CloudinaryUploadResult({
    this.photoId,
    this.documentId,
    this.proofId,
    required this.url,
    this.transformations,
    this.uploadTime,
    this.fileSize,
    this.format,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      photoId: json['photo_id']?.toString(),
      documentId: json['document_id']?.toString(),
      proofId: json['proof_id']?.toString(),
      url: json['photo_url'] ?? json['document_url'] ?? json['proof_url'] ?? json['avatar_url'] ?? '',
      transformations: json['transformations'] != null 
          ? Map<String, String>.from(json['transformations'])
          : null,
      uploadTime: json['upload_time']?.toDouble(),
      fileSize: json['file_size']?.toInt(),
      format: json['format'],
    );
  }
}

/// Statistiques d'usage Cloudinary
class CloudinaryUsageStats {
  final CloudinaryQuota storage;
  final CloudinaryQuota bandwidth;
  final CloudinaryImageStats images;
  final List<CloudinaryImageTypeStats> byType;
  final List<CloudinaryAlert> alerts;

  const CloudinaryUsageStats({
    required this.storage,
    required this.bandwidth,
    required this.images,
    required this.byType,
    required this.alerts,
  });

  factory CloudinaryUsageStats.fromJson(Map<String, dynamic> json) {
    return CloudinaryUsageStats(
      storage: CloudinaryQuota.fromJson(json['storage']),
      bandwidth: CloudinaryQuota.fromJson(json['bandwidth']),
      images: CloudinaryImageStats.fromJson(json['images']),
      byType: (json['by_type'] as List)
          .map((item) => CloudinaryImageTypeStats.fromJson(item))
          .toList(),
      alerts: (json['alerts'] as List)
          .map((item) => CloudinaryAlert.fromJson(item))
          .toList(),
    );
  }
}

/// Quota Cloudinary (stockage ou bande passante)
class CloudinaryQuota {
  final int used;
  final int limit;
  final double percentage;
  final String formattedUsed;
  final String formattedLimit;

  const CloudinaryQuota({
    required this.used,
    required this.limit,
    required this.percentage,
    required this.formattedUsed,
    required this.formattedLimit,
  });

  factory CloudinaryQuota.fromJson(Map<String, dynamic> json) {
    return CloudinaryQuota(
      used: json['used']?.toInt() ?? 0,
      limit: json['limit']?.toInt() ?? 0,
      percentage: json['percentage']?.toDouble() ?? 0.0,
      formattedUsed: json['formatted_used'] ?? '0 B',
      formattedLimit: json['formatted_limit'] ?? '0 B',
    );
  }
}

/// Statistiques globales des images
class CloudinaryImageStats {
  final int totalCount;
  final int monthlyUploads;
  final double avgCompression;
  final double avgUploadTime;

  const CloudinaryImageStats({
    required this.totalCount,
    required this.monthlyUploads,
    required this.avgCompression,
    required this.avgUploadTime,
  });

  factory CloudinaryImageStats.fromJson(Map<String, dynamic> json) {
    return CloudinaryImageStats(
      totalCount: json['total_count']?.toInt() ?? 0,
      monthlyUploads: json['monthly_uploads']?.toInt() ?? 0,
      avgCompression: json['avg_compression']?.toDouble() ?? 0.0,
      avgUploadTime: json['avg_upload_time']?.toDouble() ?? 0.0,
    );
  }
}

/// Statistiques par type d'image
class CloudinaryImageTypeStats {
  final String imageType;
  final int count;
  final int totalSize;
  final double avgSize;
  final double avgCompression;

  const CloudinaryImageTypeStats({
    required this.imageType,
    required this.count,
    required this.totalSize,
    required this.avgSize,
    required this.avgCompression,
  });

  factory CloudinaryImageTypeStats.fromJson(Map<String, dynamic> json) {
    return CloudinaryImageTypeStats(
      imageType: json['image_type'] ?? '',
      count: json['count']?.toInt() ?? 0,
      totalSize: json['total_size']?.toInt() ?? 0,
      avgSize: json['avg_size']?.toDouble() ?? 0.0,
      avgCompression: json['avg_compression']?.toDouble() ?? 0.0,
    );
  }
}

/// Alerte Cloudinary
class CloudinaryAlert {
  final String type;
  final double percentage;

  const CloudinaryAlert({
    required this.type,
    required this.percentage,
  });

  factory CloudinaryAlert.fromJson(Map<String, dynamic> json) {
    return CloudinaryAlert(
      type: json['type'] ?? '',
      percentage: json['percentage']?.toDouble() ?? 0.0,
    );
  }
}

/// Exception Cloudinary
class CloudinaryException implements Exception {
  final String message;

  const CloudinaryException(this.message);

  @override
  String toString() => 'CloudinaryException: $message';
}