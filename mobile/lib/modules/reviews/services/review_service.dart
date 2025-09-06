
import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../services/auth_token_service.dart';
import '../models/review_model.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  late final Dio _dio;

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.baseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Intercepteur pour ajouter automatiquement le token d'auth
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = AuthTokenService.instance.currentToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expiré - pour l'instant on laisse l'erreur passer
          // TODO: Implémenter le refresh token si nécessaire
        }
        handler.next(error);
      },
    ));
  }


  /// Créer une nouvelle review
  Future<void> createReview({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dio.post('/reviews', data: {
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
      });

      if (response.statusCode != 201 || response.data['success'] != true) {
        throw Exception('Erreur lors de la création de l\'évaluation');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] ?? 'Données invalides';
        throw Exception(message);
      }
      throw Exception('Erreur réseau: ${e.message}');
    }
  }

  /// Récupérer les reviews d'un utilisateur
  Future<Map<String, dynamic>> getUserReviews({
    required int userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get('/users/$userId/reviews', queryParameters: {
        'page': page,
        'limit': limit,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        
        return {
          'user_rating': data['user_rating'] != null 
              ? UserRatingModel.fromJson(data['user_rating'])
              : null,
          'reviews': (data['reviews'] as List)
              .map((review) => ReviewModel.fromJson(review))
              .toList(),
          'has_more': data['pagination']['has_more'],
        };
      }
      
      throw Exception('Erreur lors de la récupération des évaluations');
    } on DioException catch (e) {
      throw Exception('Erreur réseau: ${e.message}');
    }
  }

  /// Récupérer le rating global d'un utilisateur
  Future<UserRatingModel> getUserRating(int userId) async {
    try {
      final response = await _dio.get('/users/$userId/rating');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UserRatingModel.fromJson(response.data['data']);
      }
      
      throw Exception('Utilisateur non trouvé');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Utilisateur non trouvé');
      }
      throw Exception('Erreur réseau: ${e.message}');
    }
  }

  /// Vérifier si l'utilisateur peut créer une review pour une booking
  Future<ReviewEligibilityModel> checkReviewEligibility(int bookingId) async {
    try {
      final response = await _dio.get('/reviews/check/$bookingId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ReviewEligibilityModel.fromJson(response.data['data']);
      }
      
      throw Exception('Erreur lors de la vérification');
    } on DioException catch (e) {
      throw Exception('Erreur réseau: ${e.message}');
    }
  }

  /// Récupérer les reviews en attente pour l'utilisateur connecté
  Future<List<PendingReviewModel>> getPendingReviews() async {
    try {
      final response = await _dio.get('/reviews/pending');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        return (data['pending_reviews'] as List)
            .map((review) => PendingReviewModel.fromJson(review))
            .toList();
      }
      
      return [];
    } on DioException catch (e) {
      throw Exception('Erreur réseau: ${e.message}');
    }
  }

  /// Méthodes utilitaires pour l'affichage des étoiles
  static List<bool> getStarRating(double rating) {
    return List.generate(5, (index) => index < rating.round());
  }

  static String getRatingText(double rating, int count) {
    if (count == 0) return 'Pas d\'évaluation';
    return '${rating.toStringAsFixed(1)} ⭐ ($count avis)';
  }

  static String getBadgeColor(String status) {
    switch (status) {
      case 'super_traveler':
        return 'green';
      case 'warning':
        return 'orange';
      case 'suspended':
        return 'red';
      default:
        return 'grey';
    }
  }
}