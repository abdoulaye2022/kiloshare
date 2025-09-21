import 'dart:io';
import 'package:dio/dio.dart';
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';

class TripImageService {
  final Dio _dio;
  final AuthService _authService;
  
  TripImageService({Dio? dio, AuthService? authService}) 
    : _dio = dio ?? _createDio(),
      _authService = authService ?? AuthService.instance;

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      },
    ));
    
    return dio;
  }

  /// Upload images for a trip
  Future<List<TripImage>> uploadTripImages(String tripId, List<File> images) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripImageException('Authentication token is required. Please log in again.');
      }

      // Validate images
      for (final image in images) {
        await _validateImage(image);
      }

      // Create multipart form data
      final formData = FormData();
      
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final fileName = image.path.split('/').last;
        
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(
            image.path,
            filename: fileName,
          ),
        ));
      }

      final response = await _dio.post(
        '/trips/$tripId/images',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        final imagesData = response.data['images'] as List;
        return imagesData.map((img) => TripImage.fromJson(img)).toList();
      } else {
        throw TripImageException(response.data['message'] ?? 'Failed to upload images');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get images for a trip
  Future<List<TripImage>> getTripImages(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId/images');
      
      if (response.data['success'] == true) {
        final imagesData = response.data['images'] as List;
        return imagesData.map((img) => TripImage.fromJson(img)).toList();
      } else {
        throw TripImageException(response.data['message'] ?? 'Failed to get trip images');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Delete a trip image
  Future<void> deleteTripImage(String tripId, String imageId) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripImageException('Authentication token is required. Please log in again.');
      }

      final response = await _dio.delete(
        '/trips/$tripId/images/$imageId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      if (response.data['success'] != true) {
        throw TripImageException(response.data['message'] ?? 'Failed to delete image');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Validate image before upload
  Future<void> _validateImage(File image) async {
    // Check if file exists
    if (!await image.exists()) {
      throw const TripImageException('Selected image does not exist');
    }

    // Check file size (3MB max)
    final fileSize = await image.length();
    const maxSize = 3 * 1024 * 1024; // 3MB
    
    if (fileSize > maxSize) {
      throw const TripImageException('Image size must be less than 3MB');
    }

    // Check file extension
    final fileName = image.path.split('/').last.toLowerCase();
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    
    if (!allowedExtensions.any((ext) => fileName.endsWith(ext))) {
      throw const TripImageException('Only JPG, PNG and WebP images are allowed');
    }
  }


  TripImageException _handleDioException(DioException e) {
    if (e.response != null && e.response!.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        return TripImageException(data['message']);
      }
    }
    return TripImageException('Network error: ${e.message}');
  }
}

class TripImage {
  final String id;
  final String tripId;
  final String imagePath;
  final String imageName;
  final String imageUrl;
  final int fileSize;
  final String formattedFileSize;
  final String mimeType;
  final int uploadOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripImage({
    required this.id,
    required this.tripId,
    required this.imagePath,
    required this.imageName,
    required this.imageUrl,
    required this.fileSize,
    required this.formattedFileSize,
    required this.mimeType,
    required this.uploadOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripImage.fromJson(Map<String, dynamic> json) {
    return TripImage(
      id: json['id'].toString(),
      tripId: json['trip_id'].toString(),
      imagePath: json['image_path'] ?? '',
      imageName: json['image_name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      fileSize: json['file_size'] ?? 0,
      formattedFileSize: json['formatted_file_size'] ?? '0 B',
      mimeType: json['mime_type'] ?? '',
      uploadOrder: json['upload_order'] ?? 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'image_path': imagePath,
      'image_name': imageName,
      'image_url': imageUrl,
      'file_size': fileSize,
      'formatted_file_size': formattedFileSize,
      'mime_type': mimeType,
      'upload_order': uploadOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TripImageException implements Exception {
  final String message;

  const TripImageException(this.message);

  @override
  String toString() => 'TripImageException: $message';
}