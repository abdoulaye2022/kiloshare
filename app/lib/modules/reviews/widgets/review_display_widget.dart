import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../widgets/star_rating_widget.dart';
import '../../../widgets/optimized_cloudinary_image.dart';

class ReviewDisplayWidget extends StatelessWidget {
  final ReviewModel review;
  final bool showRoute;
  final bool showTimeAgo;

  const ReviewDisplayWidget({
    super.key,
    required this.review,
    this.showRoute = true,
    this.showTimeAgo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec utilisateur et rating
          Row(
            children: [
              // Avatar
              CloudinaryAvatar(
                imageUrl: review.reviewerAvatar,
                userName: review.reviewerFullName,
                radius: 20,
              ),
              
              const SizedBox(width: 12),
              
              // Nom et rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerFullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        StarRatingWidget(
                          rating: review.rating.toDouble(),
                          size: 14,
                        ),
                        if (showTimeAgo) ...[
                          const SizedBox(width: 8),
                          Text(
                            review.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Route si demandée
              if (showRoute && review.route.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    review.route,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          
          // Commentaire si présent
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          
          // Auto-published indicator
          if (review.autoPublishedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'Publié automatiquement',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ReviewListWidget extends StatelessWidget {
  final List<ReviewModel> reviews;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;
  final bool isLoading;

  const ReviewListWidget({
    super.key,
    required this.reviews,
    this.showLoadMore = false,
    this.onLoadMore,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty && !isLoading) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Liste des reviews
        ...reviews.map((review) => ReviewDisplayWidget(review: review)),
        
        // Bouton charger plus
        if (showLoadMore) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: isLoading ? null : onLoadMore,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Voir plus d\'évaluations'),
            ),
          ),
        ],
        
        // Loading indicator en bas
        if (isLoading && !showLoadMore) ...[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.star_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune évaluation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cet utilisateur n\'a pas encore reçu d\'évaluations.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class UserRatingHeader extends StatelessWidget {
  final UserRatingModel userRating;
  final bool showDetails;
  final VoidCallback? onTap;

  const UserRatingHeader({
    super.key,
    required this.userRating,
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          children: [
            // Rating principal
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star,
                  size: 32,
                  color: Colors.amber[600],
                ),
                const SizedBox(width: 8),
                Text(
                  userRating.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '/5',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Nombre d'avis
            Text(
              '${userRating.totalReviews} avis',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            // Badge si applicable
            if (userRating.badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getBadgeColor(userRating.status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  userRating.badges.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            
            // Détails si demandés
            if (showDetails && userRating.hasReviews) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'En tant que voyageur',
                      userRating.asTravelerRating,
                      userRating.asTravelerCount,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'En tant qu\'expéditeur',
                      userRating.asSenderRating,
                      userRating.asSenderCount,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double rating, int count) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (count > 0) ...[
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$count avis',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ] else ...[
          Text(
            'Pas d\'avis',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  Color _getBadgeColor(String status) {
    switch (status) {
      case 'super_traveler':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class CompactRatingDisplay extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final String status;
  final bool showBadge;

  const CompactRatingDisplay({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.status,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return const Text(
        'Nouveau',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBadge(
          rating: rating,
          reviewCount: reviewCount,
          status: status,
          showBadge: showBadge,
          compact: true,
        ),
      ],
    );
  }
}