import '../modules/trips/models/trip_model.dart';
import '../modules/trips/models/trip_image_model.dart';

/// Test utilitaire pour vérifier la déduplication des images
void testImageDeduplication() {
  print('🧪 Test de déduplication des images');

  // Créer des données de test avec des images dupliquées
  final testJson = {
    'id': '1',
    'uuid': 'test-uuid',
    'user_id': '1',
    'transport_type': 'flight',
    'departure_city': 'Montreal',
    'departure_country': 'Canada',
    'departure_date': '2025-09-24T00:00:00Z',
    'arrival_city': 'Paris',
    'arrival_country': 'France',
    'arrival_date': '2025-09-24T08:00:00Z',
    'available_weight_kg': 10.0,
    'price_per_kg': 5.0,
    'currency': 'CAD',
    'status': 'active',
    'view_count': 0,
    'booking_count': 0,
    'images': [
      {
        'id': '1',
        'url': 'https://example.com/image1.jpg',
        'alt_text': 'Image 1',
        'is_primary': true
      },
      'https://example.com/image1.jpg', // Duplicate URL as string
      {
        'id': '2',
        'url': 'https://example.com/image2.jpg',
        'alt_text': 'Image 2',
        'is_primary': false
      },
      {
        'id': '3',
        'url': 'https://example.com/image1.jpg', // Duplicate URL as object
        'alt_text': 'Image 1 duplicate',
        'is_primary': false
      },
      'https://example.com/image3.jpg',
      'https://example.com/image3.jpg', // Duplicate string
    ]
  };

  try {
    // Parser le trip avec les données de test
    final trip = Trip.fromJson(testJson);

    print('📊 Résultats du test :');
    final originalImages = testJson['images'] as List;
    print('   • Images originales dans JSON: ${originalImages.length}');
    print('   • Images parsées (trip.images): ${trip.images?.length ?? 0}');
    print('   • Images uniques (trip.uniqueImages): ${trip.uniqueImages?.length ?? 0}');
    print('   • hasImages: ${trip.hasImages}');
    print('   • imageCount: ${trip.imageCount}');

    if (trip.uniqueImages != null) {
      print('📋 URLs des images uniques :');
      for (int i = 0; i < trip.uniqueImages!.length; i++) {
        final image = trip.uniqueImages![i];
        print('   ${i + 1}. ${image.url} (primary: ${image.isPrimary})');
      }
    }

    // Vérifications
    final expectedUniqueCount = 3; // image1.jpg, image2.jpg, image3.jpg
    final actualUniqueCount = trip.uniqueImages?.length ?? 0;

    if (actualUniqueCount == expectedUniqueCount) {
      print('✅ Test réussi : ${actualUniqueCount} images uniques détectées');
    } else {
      print('❌ Test échoué : Attendu ${expectedUniqueCount}, obtenu ${actualUniqueCount}');
    }

    // Vérifier l'image primaire
    final primaryImage = trip.primaryImage;
    if (primaryImage != null && primaryImage.url == 'https://example.com/image1.jpg') {
      print('✅ Image primaire correcte : ${primaryImage.url}');
    } else {
      print('❌ Problème avec l\'image primaire');
    }

  } catch (e) {
    print('❌ Erreur lors du test : $e');
  }

  print('🏁 Test terminé\n');
}

/// Fonction pour tester avec des données réelles
void testWithRealData(Trip trip) {
  print('🔍 Test avec données réelles :');
  print('   • Images brutes : ${trip.images?.length ?? 0}');
  print('   • Images uniques : ${trip.uniqueImages?.length ?? 0}');
  print('   • hasImages : ${trip.hasImages}');

  if (trip.images != null && trip.uniqueImages != null) {
    final duplicatesRemoved = trip.images!.length - trip.uniqueImages!.length;
    if (duplicatesRemoved > 0) {
      print('   • 🗑️ ${duplicatesRemoved} doublons supprimés');
    } else {
      print('   • ✅ Aucun doublon détecté');
    }
  }
}