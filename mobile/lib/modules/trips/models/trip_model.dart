import 'dart:convert';
import 'trip_image_model.dart';

// Helper functions for JSON parsing
double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

bool _parseBool(dynamic value, [bool defaultValue = false]) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is double) return value != 0.0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
    return defaultValue;
  }
  return defaultValue;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

dynamic _parseJsonString(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        return jsonDecode(value);
      } catch (e) {
        return value; // Return original string if JSON parsing fails
      }
    }
  }
  return value;
}

class Trip {
  final String id;
  final String uuid;
  final String userId;
  final String transportType;
  
  // Departure info
  final String departureCity;
  final String departureCountry;
  final String? departureAirportCode;
  final DateTime departureDate;
  
  // Arrival info
  final String arrivalCity;
  final String arrivalCountry;
  final String? arrivalAirportCode;
  final DateTime arrivalDate;
  
  // Capacity and pricing
  final double availableWeightKg;
  final double pricePerKg;
  final String currency;
  
  // Flight info
  final String? flightNumber;
  final String? airline;
  final bool ticketVerified;
  final DateTime? ticketVerificationDate;
  
  // Status and metadata
  final TripStatus status;
  final int viewCount;
  final int bookingCount;
  final bool? isOwner;
  
  // Description
  final String? description;
  final String? specialNotes;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // NEW: Status tracking dates
  final DateTime? publishedAt;
  final DateTime? pausedAt;
  final DateTime? cancelledAt;
  final DateTime? archivedAt;
  final DateTime? expiredAt;
  final DateTime? rejectedAt;
  final DateTime? completedAt;
  
  // NEW: Reasons and notes
  final String? rejectionReason;
  final Map<String, dynamic>? rejectionDetails;
  final String? cancellationReason;
  final String? cancellationDetails;
  final String? pauseReason;
  
  // NEW: Moderation
  final bool isApproved;
  final bool autoApproved;
  final int? moderatedBy;
  final String? moderationNotes;
  final int? trustScoreAtCreation;
  final bool requiresManualReview;
  final String reviewPriority;
  
  // NEW: Metrics
  final int shareCount;
  final int favoriteCount;
  final int reportCount;
  final int duplicateCount;
  final int editCount;
  final double totalBookedWeight;
  final double remainingWeight;
  
  // NEW: Flags and options
  final bool isUrgent;
  final bool isFeatured;
  final bool isVerified;
  final bool autoExpire;
  final bool allowPartialBooking;
  final bool instantBooking;
  
  // NEW: Visibility
  final String visibility;
  final double minUserRating;
  final int minUserTrips;
  final List<int>? blockedUsers;
  
  // NEW: SEO and sharing
  final String? slug;
  final String? metaTitle;
  final String? metaDescription;
  final String? shareToken;
  
  // NEW: Versioning
  final int version;
  final DateTime? lastMajorEdit;
  final int? originalTripId;
  
  // Additional data for display
  final TripUser? user;
  final List<String>? restrictedCategories;
  final List<String>? restrictedItems;
  final String? restrictionNotes;
  final List<TripImage>? images;

  const Trip({
    required this.id,
    required this.uuid,
    required this.userId,
    required this.transportType,
    required this.departureCity,
    required this.departureCountry,
    this.departureAirportCode,
    required this.departureDate,
    required this.arrivalCity,
    required this.arrivalCountry,
    this.arrivalAirportCode,
    required this.arrivalDate,
    required this.availableWeightKg,
    required this.pricePerKg,
    this.currency = 'CAD',
    this.flightNumber,
    this.airline,
    this.ticketVerified = false,
    this.ticketVerificationDate,
    this.status = TripStatus.draft,
    this.viewCount = 0,
    this.bookingCount = 0,
    this.isOwner,
    this.description,
    this.specialNotes,
    required this.createdAt,
    required this.updatedAt,
    
    // NEW: Status tracking dates
    this.publishedAt,
    this.pausedAt,
    this.cancelledAt,
    this.archivedAt,
    this.expiredAt,
    this.rejectedAt,
    this.completedAt,
    
    // NEW: Reasons and notes
    this.rejectionReason,
    this.rejectionDetails,
    this.cancellationReason,
    this.cancellationDetails,
    this.pauseReason,
    
    // NEW: Moderation
    this.isApproved = false,
    this.autoApproved = false,
    this.moderatedBy,
    this.moderationNotes,
    this.trustScoreAtCreation,
    this.requiresManualReview = false,
    this.reviewPriority = 'medium',
    
    // NEW: Metrics
    this.shareCount = 0,
    this.favoriteCount = 0,
    this.reportCount = 0,
    this.duplicateCount = 0,
    this.editCount = 0,
    this.totalBookedWeight = 0.0,
    this.remainingWeight = 0.0,
    
    // NEW: Flags and options
    this.isUrgent = false,
    this.isFeatured = false,
    this.isVerified = false,
    this.autoExpire = true,
    this.allowPartialBooking = true,
    this.instantBooking = false,
    
    // NEW: Visibility
    this.visibility = 'public',
    this.minUserRating = 0.0,
    this.minUserTrips = 0,
    this.blockedUsers,
    
    // NEW: SEO and sharing
    this.slug,
    this.metaTitle,
    this.metaDescription,
    this.shareToken,
    
    // NEW: Versioning
    this.version = 1,
    this.lastMajorEdit,
    this.originalTripId,
    
    // Additional data
    this.user,
    this.restrictedCategories,
    this.restrictedItems,
    this.restrictionNotes,
    this.images,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    print('🔥 Trip.fromJson: Starting to parse trip data...');
    print('🔥 Trip.fromJson: Input data type: ${json.runtimeType}');
    print('🔥 Trip.fromJson: Input data keys: ${json.keys.toList()}');
    
    try {
      return Trip(
        id: json['id']?.toString() ?? '',
        uuid: json['uuid'] ?? '',
        userId: json['user_id']?.toString() ?? '',
        transportType: json['transport_type'] ?? 'car',
      departureCity: json['departure_city'] ?? '',
      departureCountry: json['departure_country'] ?? '',
      departureAirportCode: json['departure_airport_code'],
      departureDate: _parseDateTime(json['departure_date']) ?? DateTime.now(),
      arrivalCity: json['arrival_city'] ?? '',
      arrivalCountry: json['arrival_country'] ?? '',
      arrivalAirportCode: json['arrival_airport_code'],
      arrivalDate: _parseDateTime(json['arrival_date']) ?? DateTime.now(),
      availableWeightKg: _parseDouble(json['available_weight_kg']) ?? _parseDouble(json['available_weight']) ?? _parseDouble(json['max_weight']) ?? 0.0,
      pricePerKg: _parseDouble(json['price_per_kg']),
      currency: json['currency'] ?? 'CAD',
      flightNumber: json['flight_number'],
      airline: json['airline'],
      ticketVerified: _parseBool(json['ticket_verified']),
      ticketVerificationDate: _parseDateTime(json['ticket_verification_date']),
      status: TripStatus.fromString(json['status'] ?? 'draft'),
      viewCount: _parseInt(json['view_count']),
      bookingCount: _parseInt(json['booking_count']),
      isOwner: _parseBool(json['is_owner']),
      description: json['description'],
      specialNotes: json['special_notes'],
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      
      // NEW: Status tracking dates
      publishedAt: _parseDateTime(json['published_at']),
      pausedAt: _parseDateTime(json['paused_at']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
      archivedAt: _parseDateTime(json['archived_at']),
      expiredAt: _parseDateTime(json['expired_at']),
      rejectedAt: _parseDateTime(json['rejected_at']),
      completedAt: _parseDateTime(json['completed_at']),
      
      // NEW: Reasons and notes
      rejectionReason: json['rejection_reason'],
      rejectionDetails: _parseJsonString(json['rejection_details']),
      cancellationReason: json['cancellation_reason'],
      cancellationDetails: json['cancellation_details'],
      pauseReason: json['pause_reason'],
      
      // NEW: Moderation
      isApproved: _parseBool(json['is_approved']),
      autoApproved: _parseBool(json['auto_approved']),
      moderatedBy: json['moderated_by'] != null ? _parseInt(json['moderated_by']) : null,
      moderationNotes: json['moderation_notes'],
      trustScoreAtCreation: json['trust_score_at_creation'] != null ? _parseInt(json['trust_score_at_creation']) : null,
      requiresManualReview: _parseBool(json['requires_manual_review']),
      reviewPriority: json['review_priority'] ?? 'medium',
      
      // NEW: Metrics
      shareCount: _parseInt(json['share_count']),
      favoriteCount: _parseInt(json['favorite_count']),
      reportCount: _parseInt(json['report_count']),
      duplicateCount: _parseInt(json['duplicate_count']),
      editCount: _parseInt(json['edit_count']),
      totalBookedWeight: _parseDouble(json['total_booked_weight']),
      remainingWeight: _parseDouble(json['remaining_weight']),
      
      // NEW: Flags and options
      isUrgent: _parseBool(json['is_urgent']),
      isFeatured: _parseBool(json['is_featured']),
      isVerified: _parseBool(json['is_verified']),
      autoExpire: _parseBool(json['auto_expire'], true),
      allowPartialBooking: _parseBool(json['allow_partial_booking'], true),
      instantBooking: _parseBool(json['instant_booking']),
      
      // NEW: Visibility
      visibility: json['visibility'] ?? 'public',
      minUserRating: _parseDouble(json['min_user_rating']),
      minUserTrips: _parseInt(json['min_user_trips']),
      blockedUsers: json['blocked_users'] != null && json['blocked_users'] is List
          ? List<int>.from(json['blocked_users'].where((item) => item != null).map((item) => int.tryParse(item.toString()) ?? 0))
          : null,
      
      // NEW: SEO and sharing
      slug: json['slug'],
      metaTitle: json['meta_title'],
      metaDescription: json['meta_description'],
      shareToken: json['share_token'],
      
      // NEW: Versioning
      version: _parseInt(json['version'], 1),
      lastMajorEdit: _parseDateTime(json['last_major_edit']),
      originalTripId: json['original_trip_id'] != null ? _parseInt(json['original_trip_id']) : null,
      
      // Additional data
      user: json['user'] != null ? TripUser.fromJson(json['user']) : null,
      restrictedCategories: json['restricted_categories'] != null && json['restricted_categories'] is List
          ? List<String>.from(json['restricted_categories'].where((item) => item != null).map((item) => item.toString()))
          : null,
      restrictedItems: json['restricted_items'] != null && json['restricted_items'] is List
          ? List<String>.from(json['restricted_items'].where((item) => item != null).map((item) => item.toString()))
          : null,
      restrictionNotes: json['restriction_notes'],
      images: json['images'] != null && json['images'] is List
          ? List<TripImage>.from(json['images'].where((item) => item != null).map((item) {
              // Handle both string URLs and TripImage objects
              if (item is String) {
                // If it's a URL string, create a TripImage object
                return TripImage(
                  id: '', // ID not available from string URL
                  url: item,
                  altText: null,
                );
              } else if (item is Map<String, dynamic>) {
                // If it's an object, parse normally
                return TripImage.fromJson(item);
              } else {
                throw Exception('Invalid image data type: ${item.runtimeType}');
              }
            }))
          : null,
      );
    } catch (e) {
      print('❌ Trip.fromJson: Error parsing trip: $e');
      print('❌ Trip.fromJson: Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'user_id': userId,
      'transport_type': transportType,
      'departure_city': departureCity,
      'departure_country': departureCountry,
      'departure_airport_code': departureAirportCode,
      'departure_date': departureDate.toIso8601String(),
      'arrival_city': arrivalCity,
      'arrival_country': arrivalCountry,
      'arrival_airport_code': arrivalAirportCode,
      'arrival_date': arrivalDate.toIso8601String(),
      'available_weight_kg': availableWeightKg,
      'price_per_kg': pricePerKg,
      'currency': currency,
      'flight_number': flightNumber,
      'airline': airline,
      'ticket_verified': ticketVerified,
      'ticket_verification_date': ticketVerificationDate?.toIso8601String(),
      'status': status.value,
      'view_count': viewCount,
      'booking_count': bookingCount,
      'is_owner': isOwner,
      'description': description,
      'special_notes': specialNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      
      // NEW: Status tracking dates
      'published_at': publishedAt?.toIso8601String(),
      'paused_at': pausedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'expired_at': expiredAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      
      // NEW: Reasons and notes
      'rejection_reason': rejectionReason,
      'rejection_details': rejectionDetails != null ? jsonEncode(rejectionDetails) : null,
      'cancellation_reason': cancellationReason,
      'cancellation_details': cancellationDetails,
      'pause_reason': pauseReason,
      
      // NEW: Moderation
      'is_approved': isApproved,
      'auto_approved': autoApproved,
      'moderated_by': moderatedBy,
      'moderation_notes': moderationNotes,
      'trust_score_at_creation': trustScoreAtCreation,
      'requires_manual_review': requiresManualReview,
      'review_priority': reviewPriority,
      
      // NEW: Metrics
      'share_count': shareCount,
      'favorite_count': favoriteCount,
      'report_count': reportCount,
      'duplicate_count': duplicateCount,
      'edit_count': editCount,
      'total_booked_weight': totalBookedWeight,
      'remaining_weight': remainingWeight,
      
      // NEW: Flags and options
      'is_urgent': isUrgent,
      'is_featured': isFeatured,
      'is_verified': isVerified,
      'auto_expire': autoExpire,
      'allow_partial_booking': allowPartialBooking,
      'instant_booking': instantBooking,
      
      // NEW: Visibility
      'visibility': visibility,
      'min_user_rating': minUserRating,
      'min_user_trips': minUserTrips,
      'blocked_users': blockedUsers,
      
      // NEW: SEO and sharing
      'slug': slug,
      'meta_title': metaTitle,
      'meta_description': metaDescription,
      'share_token': shareToken,
      
      // NEW: Versioning
      'version': version,
      'last_major_edit': lastMajorEdit?.toIso8601String(),
      'original_trip_id': originalTripId,
      
      if (user != null) 'user': user!.toJson(),
      if (restrictedCategories != null) 'restricted_categories': restrictedCategories,
      if (restrictedItems != null) 'restricted_items': restrictedItems,
      if (restrictionNotes != null) 'restriction_notes': restrictionNotes,
      if (images != null) 'images': images!.map((img) => img.toJson()).toList(),
    };
  }

  Trip copyWith({
    String? id,
    String? uuid,
    String? userId,
    String? transportType,
    String? departureCity,
    String? departureCountry,
    String? departureAirportCode,
    DateTime? departureDate,
    String? arrivalCity,
    String? arrivalCountry,
    String? arrivalAirportCode,
    DateTime? arrivalDate,
    double? availableWeightKg,
    double? pricePerKg,
    String? currency,
    String? flightNumber,
    String? airline,
    bool? ticketVerified,
    DateTime? ticketVerificationDate,
    TripStatus? status,
    int? viewCount,
    int? bookingCount,
    bool? isOwner,
    String? description,
    String? specialNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    
    // NEW: Status tracking dates
    DateTime? publishedAt,
    DateTime? pausedAt,
    DateTime? cancelledAt,
    DateTime? archivedAt,
    DateTime? expiredAt,
    DateTime? rejectedAt,
    DateTime? completedAt,
    
    // NEW: Reasons and notes
    String? rejectionReason,
    Map<String, dynamic>? rejectionDetails,
    String? cancellationReason,
    String? cancellationDetails,
    String? pauseReason,
    
    // NEW: Moderation
    bool? isApproved,
    bool? autoApproved,
    int? moderatedBy,
    String? moderationNotes,
    int? trustScoreAtCreation,
    bool? requiresManualReview,
    String? reviewPriority,
    
    // NEW: Metrics
    int? shareCount,
    int? favoriteCount,
    int? reportCount,
    int? duplicateCount,
    int? editCount,
    double? totalBookedWeight,
    double? remainingWeight,
    
    // NEW: Flags and options
    bool? isUrgent,
    bool? isFeatured,
    bool? isVerified,
    bool? autoExpire,
    bool? allowPartialBooking,
    bool? instantBooking,
    
    // NEW: Visibility
    String? visibility,
    double? minUserRating,
    int? minUserTrips,
    List<int>? blockedUsers,
    
    // NEW: SEO and sharing
    String? slug,
    String? metaTitle,
    String? metaDescription,
    String? shareToken,
    
    // NEW: Versioning
    int? version,
    DateTime? lastMajorEdit,
    int? originalTripId,
    
    // Additional data
    TripUser? user,
    List<String>? restrictedCategories,
    List<String>? restrictedItems,
    String? restrictionNotes,
    List<TripImage>? images,
  }) {
    return Trip(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      transportType: transportType ?? this.transportType,
      departureCity: departureCity ?? this.departureCity,
      departureCountry: departureCountry ?? this.departureCountry,
      departureAirportCode: departureAirportCode ?? this.departureAirportCode,
      departureDate: departureDate ?? this.departureDate,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      arrivalCountry: arrivalCountry ?? this.arrivalCountry,
      arrivalAirportCode: arrivalAirportCode ?? this.arrivalAirportCode,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      availableWeightKg: availableWeightKg ?? this.availableWeightKg,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      currency: currency ?? this.currency,
      flightNumber: flightNumber ?? this.flightNumber,
      airline: airline ?? this.airline,
      ticketVerified: ticketVerified ?? this.ticketVerified,
      ticketVerificationDate: ticketVerificationDate ?? this.ticketVerificationDate,
      status: status ?? this.status,
      viewCount: viewCount ?? this.viewCount,
      bookingCount: bookingCount ?? this.bookingCount,
      isOwner: isOwner ?? this.isOwner,
      description: description ?? this.description,
      specialNotes: specialNotes ?? this.specialNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      
      // NEW: Status tracking dates
      publishedAt: publishedAt ?? this.publishedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      archivedAt: archivedAt ?? this.archivedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      completedAt: completedAt ?? this.completedAt,
      
      // NEW: Reasons and notes
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectionDetails: rejectionDetails ?? this.rejectionDetails,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationDetails: cancellationDetails ?? this.cancellationDetails,
      pauseReason: pauseReason ?? this.pauseReason,
      
      // NEW: Moderation
      isApproved: isApproved ?? this.isApproved,
      autoApproved: autoApproved ?? this.autoApproved,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      moderationNotes: moderationNotes ?? this.moderationNotes,
      trustScoreAtCreation: trustScoreAtCreation ?? this.trustScoreAtCreation,
      requiresManualReview: requiresManualReview ?? this.requiresManualReview,
      reviewPriority: reviewPriority ?? this.reviewPriority,
      
      // NEW: Metrics
      shareCount: shareCount ?? this.shareCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      reportCount: reportCount ?? this.reportCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      editCount: editCount ?? this.editCount,
      totalBookedWeight: totalBookedWeight ?? this.totalBookedWeight,
      remainingWeight: remainingWeight ?? this.remainingWeight,
      
      // NEW: Flags and options
      isUrgent: isUrgent ?? this.isUrgent,
      isFeatured: isFeatured ?? this.isFeatured,
      isVerified: isVerified ?? this.isVerified,
      autoExpire: autoExpire ?? this.autoExpire,
      allowPartialBooking: allowPartialBooking ?? this.allowPartialBooking,
      instantBooking: instantBooking ?? this.instantBooking,
      
      // NEW: Visibility
      visibility: visibility ?? this.visibility,
      minUserRating: minUserRating ?? this.minUserRating,
      minUserTrips: minUserTrips ?? this.minUserTrips,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      
      // NEW: SEO and sharing
      slug: slug ?? this.slug,
      metaTitle: metaTitle ?? this.metaTitle,
      metaDescription: metaDescription ?? this.metaDescription,
      shareToken: shareToken ?? this.shareToken,
      
      // NEW: Versioning
      version: version ?? this.version,
      lastMajorEdit: lastMajorEdit ?? this.lastMajorEdit,
      originalTripId: originalTripId ?? this.originalTripId,
      
      // Additional data
      user: user ?? this.user,
      restrictedCategories: restrictedCategories ?? this.restrictedCategories,
      restrictedItems: restrictedItems ?? this.restrictedItems,
      restrictionNotes: restrictionNotes ?? this.restrictionNotes,
      images: images ?? this.images,
    );
  }

  // Business logic methods
  bool get isEditable => 
    (status == TripStatus.draft || status == TripStatus.active || status == TripStatus.rejected) &&
    departureDate.isAfter(DateTime.now());

  bool get canBePublished => 
    (status == TripStatus.draft || status == TripStatus.rejected) &&
    departureDate.isAfter(DateTime.now());

  bool get isPendingApproval => status == TripStatus.pendingApproval;
  bool get isRejected => status == TripStatus.rejected;
  bool get isPendingReview => status == TripStatus.pendingReview;

  int get remainingDays {
    final difference = departureDate.difference(DateTime.now()).inDays;
    return difference > 0 ? difference : 0;
  }

  double get totalEarningsPotential => availableWeightKg * pricePerKg;

  String get routeDisplay => '$departureCity → $arrivalCity';

  String get durationDisplay {
    final duration = arrivalDate.difference(departureDate);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}';
    } else {
      return '${minutes}min';
    }
  }

  // Images helper methods
  TripImage? get primaryImage => images?.where((img) => img.isPrimary).firstOrNull;
  
  TripImage? get firstImage => images?.isNotEmpty == true ? images!.first : null;
  
  bool get hasImages => images?.isNotEmpty == true;
  
  int get imageCount => images?.length ?? 0;
}

enum TripStatus {
  draft('draft'),
  pendingReview('pending_review'),
  pendingApproval('pending_approval'), // Keep for backward compatibility
  active('active'),
  rejected('rejected'),
  booked('booked'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  paused('paused'),
  expired('expired');

  const TripStatus(this.value);
  final String value;

  static TripStatus fromString(String value) {
    return TripStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TripStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case TripStatus.draft:
        return 'Brouillon';
      case TripStatus.pendingReview:
        return 'En attente de révision';
      case TripStatus.pendingApproval:
        return 'En attente d\'approbation';
      case TripStatus.active:
        return 'Actif';
      case TripStatus.rejected:
        return 'Rejeté';
      case TripStatus.booked:
        return 'Réservé';
      case TripStatus.inProgress:
        return 'En cours';
      case TripStatus.completed:
        return 'Terminé';
      case TripStatus.cancelled:
        return 'Annulé';
      case TripStatus.paused:
        return 'En pause';
      case TripStatus.expired:
        return 'Expiré';
    }
  }
}

class TripUser {
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final bool isVerified;

  const TripUser({
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.isVerified = false,
  });

  factory TripUser.fromJson(Map<String, dynamic> json) {
    return TripUser(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      profilePicture: json['profile_picture'],
      isVerified: _parseBool(json['is_verified']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'profile_picture': profilePicture,
      'is_verified': isVerified,
    };
  }

  String get displayName => '$firstName $lastName'.trim();
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
}

class PriceSuggestion {
  final int distanceKm;
  final double basePricePerKg;
  final double commissionRate;
  final double suggestedPricePerKg;
  final String currency;
  final Map<String, double> exchangeRates;

  const PriceSuggestion({
    required this.distanceKm,
    required this.basePricePerKg,
    required this.commissionRate,
    required this.suggestedPricePerKg,
    required this.currency,
    required this.exchangeRates,
  });

  factory PriceSuggestion.fromJson(Map<String, dynamic> json) {
    return PriceSuggestion(
      distanceKm: (json['distance_km'] as num?)?.toInt() ?? 0,
      basePricePerKg: (json['base_price_per_kg'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 15.0,
      suggestedPricePerKg: (json['suggested_price_per_kg'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'CAD',
      exchangeRates: _safeMapToDouble(json['exchange_rates']),
    );
  }
  
  static Map<String, double> _safeMapToDouble(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, (val as num?)?.toDouble() ?? 0.0));
    }
    return {};
  }
}

class PriceBreakdown {
  final double pricePerKg;
  final double weightKg;
  final double subtotal;
  final double commission;
  final double commissionRate;
  final double carrierEarnings;
  final String currency;

  const PriceBreakdown({
    required this.pricePerKg,
    required this.weightKg,
    required this.subtotal,
    required this.commission,
    required this.commissionRate,
    required this.carrierEarnings,
    required this.currency,
  });

  factory PriceBreakdown.fromJson(Map<String, dynamic> json) {
    return PriceBreakdown(
      pricePerKg: (json['price_per_kg'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 15.0,
      carrierEarnings: (json['carrier_earnings'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'CAD',
    );
  }
}