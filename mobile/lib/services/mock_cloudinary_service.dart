import 'dart:io';

/// Service temporaire qui simule l'upload Cloudinary
/// À remplacer par le vrai service Cloudinary une fois configuré
class MockCloudinaryService {
  
  /// Simule l'upload multiple de photos de voyage
  Future<List<Map<String, dynamic>>> uploadTripPhotos(
    List<File> imageFiles, {
    Function(double)? onProgress,
  }) async {
    
    // Simuler un délai d'upload
    await Future.delayed(const Duration(milliseconds: 500));
    
    final results = <Map<String, dynamic>>[];
    
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      
      // Simuler la progression
      if (onProgress != null) {
        onProgress((i + 1) / imageFiles.length);
      }
      
      // Créer des données simulées
      results.add({
        'url': 'https://res.cloudinary.com/demo/image/upload/mock_trip_image_$i.jpg',
        'public_id': 'kiloshare/trips/mock_trip_${DateTime.now().millisecondsSinceEpoch}_$i',
        'thumbnail': 'https://res.cloudinary.com/demo/image/upload/c_fill,w_300,h_200/mock_trip_image_$i.jpg',
        'width': 800,
        'height': 600,
        'file_size': file.lengthSync(),
        'format': 'jpg',
        'is_primary': i == 0,
        'alt_text': null,
        'order': i,
      });
    }
    
    return results;
  }
}