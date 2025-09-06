class ReviewModel {
  final int id;
  final int bookingId;
  final int reviewerId;
  final int reviewedId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final bool isVisible;
  final DateTime? autoPublishedAt;
  
  // Informations du reviewer (si incluses)
  final String? reviewerFirstName;
  final String? reviewerLastName;
  final String? reviewerAvatar;
  
  // Informations du voyage (si incluses)
  final int? tripId;
  final String? departureCity;
  final String? arrivalCity;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.reviewedId,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.isVisible,
    this.autoPublishedAt,
    this.reviewerFirstName,
    this.reviewerLastName,
    this.reviewerAvatar,
    this.tripId,
    this.departureCity,
    this.arrivalCity,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'],
      bookingId: json['booking_id'],
      reviewerId: json['reviewer_id'],
      reviewedId: json['reviewed_id'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      isVisible: json['is_visible'] == 1 || json['is_visible'] == true,
      autoPublishedAt: json['auto_published_at'] != null 
          ? DateTime.parse(json['auto_published_at']) 
          : null,
      reviewerFirstName: json['reviewer_first_name'],
      reviewerLastName: json['reviewer_last_name'],
      reviewerAvatar: json['reviewer_avatar'],
      tripId: json['trip_id'],
      departureCity: json['departure_city'],
      arrivalCity: json['arrival_city'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'reviewer_id': reviewerId,
      'reviewed_id': reviewedId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'is_visible': isVisible,
      'auto_published_at': autoPublishedAt?.toIso8601String(),
      'reviewer_first_name': reviewerFirstName,
      'reviewer_last_name': reviewerLastName,
      'reviewer_avatar': reviewerAvatar,
      'trip_id': tripId,
      'departure_city': departureCity,
      'arrival_city': arrivalCity,
    };
  }

  String get reviewerFullName {
    if (reviewerFirstName != null && reviewerLastName != null) {
      return '$reviewerFirstName $reviewerLastName';
    }
    return 'Utilisateur';
  }

  String get route {
    if (departureCity != null && arrivalCity != null) {
      return '$departureCity → $arrivalCity';
    }
    return '';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }
}

class UserRatingModel {
  final int userId;
  final double averageRating;
  final int totalReviews;
  final double asTravelerRating;
  final int asTravelerCount;
  final double asSenderRating;
  final int asSenderCount;
  final String status;
  final List<String> badges;
  final List<String> recentComments;
  final DateTime lastUpdated;

  UserRatingModel({
    required this.userId,
    required this.averageRating,
    required this.totalReviews,
    required this.asTravelerRating,
    required this.asTravelerCount,
    required this.asSenderRating,
    required this.asSenderCount,
    required this.status,
    required this.badges,
    required this.recentComments,
    required this.lastUpdated,
  });

  factory UserRatingModel.fromJson(Map<String, dynamic> json) {
    return UserRatingModel(
      userId: json['user_id'],
      averageRating: (json['average_rating'] as num).toDouble(),
      totalReviews: json['total_reviews'],
      asTravelerRating: (json['as_traveler_rating'] as num).toDouble(),
      asTravelerCount: json['as_traveler_count'],
      asSenderRating: (json['as_sender_rating'] as num).toDouble(),
      asSenderCount: json['as_sender_count'],
      status: json['status'] ?? 'normal',
      badges: List<String>.from(json['badges'] ?? []),
      recentComments: List<String>.from(json['recent_comments'] ?? []),
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'as_traveler_rating': asTravelerRating,
      'as_traveler_count': asTravelerCount,
      'as_sender_rating': asSenderRating,
      'as_sender_count': asSenderCount,
      'status': status,
      'badges': badges,
      'recent_comments': recentComments,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  bool get hasReviews => totalReviews > 0;
  bool get isSuperTraveler => status == 'super_traveler';
  bool get hasWarning => status == 'warning';
  bool get isSuspended => status == 'suspended';

  String get displayRating {
    if (totalReviews == 0) return 'Nouveau';
    return '${averageRating.toStringAsFixed(1)} ⭐';
  }

  String get badgeText {
    if (badges.isNotEmpty) return badges.first;
    if (totalReviews == 0) return 'Nouveau';
    return '';
  }
}

class PendingReviewModel {
  final int bookingId;
  final String userRole; // 'sender' or 'traveler'
  final String route;
  final DateTime deliveredAt;

  PendingReviewModel({
    required this.bookingId,
    required this.userRole,
    required this.route,
    required this.deliveredAt,
  });

  factory PendingReviewModel.fromJson(Map<String, dynamic> json) {
    return PendingReviewModel(
      bookingId: json['booking_id'],
      userRole: json['user_role'],
      route: json['route'],
      deliveredAt: DateTime.parse(json['delivered_at']),
    );
  }

  String get roleDisplayName {
    return userRole == 'sender' ? 'Expéditeur' : 'Voyageur';
  }

  String get timeElapsed {
    final now = DateTime.now();
    final difference = now.difference(deliveredAt);
    
    if (difference.inDays > 0) {
      return 'Livré il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Livré il y a ${difference.inHours}h';
    } else {
      return 'Livré récemment';
    }
  }
}

class ReviewEligibilityModel {
  final bool canReview;
  final String? reason;
  final String? userRole;
  final Map<String, dynamic>? bookingInfo;

  ReviewEligibilityModel({
    required this.canReview,
    this.reason,
    this.userRole,
    this.bookingInfo,
  });

  factory ReviewEligibilityModel.fromJson(Map<String, dynamic> json) {
    return ReviewEligibilityModel(
      canReview: json['can_review'],
      reason: json['reason'],
      userRole: json['user_role'],
      bookingInfo: json['booking_info'],
    );
  }

  String get reasonMessage {
    switch (reason) {
      case 'booking_not_found':
        return 'Réservation non trouvée';
      case 'not_participant':
        return 'Vous ne participez pas à cette réservation';
      case 'not_delivered':
        return 'La réservation n\'est pas encore livrée';
      case 'too_early':
        return 'Vous devez attendre 24h après la livraison';
      case 'already_reviewed':
        return 'Vous avez déjà évalué cette réservation';
      default:
        return reason ?? 'Impossible d\'évaluer';
    }
  }
}