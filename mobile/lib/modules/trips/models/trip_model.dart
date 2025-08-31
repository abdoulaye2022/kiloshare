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
  
  // Description
  final String? description;
  final String? specialNotes;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional data for display
  final TripUser? user;
  final List<String>? restrictedCategories;
  final List<String>? restrictedItems;
  final String? restrictionNotes;

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
    this.description,
    this.specialNotes,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.restrictedCategories,
    this.restrictedItems,
    this.restrictionNotes,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      uuid: json['uuid'] ?? '',
      userId: json['user_id']?.toString() ?? '',
      transportType: json['transport_type'] ?? 'car',
      departureCity: json['departure_city'] ?? '',
      departureCountry: json['departure_country'] ?? '',
      departureAirportCode: json['departure_airport_code'],
      departureDate: DateTime.parse(json['departure_date']),
      arrivalCity: json['arrival_city'] ?? '',
      arrivalCountry: json['arrival_country'] ?? '',
      arrivalAirportCode: json['arrival_airport_code'],
      arrivalDate: DateTime.parse(json['arrival_date']),
      availableWeightKg: (json['available_weight_kg'] as num?)?.toDouble() ?? 0.0,
      pricePerKg: (json['price_per_kg'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'CAD',
      flightNumber: json['flight_number'],
      airline: json['airline'],
      ticketVerified: json['ticket_verified'] ?? false,
      ticketVerificationDate: json['ticket_verification_date'] != null
          ? DateTime.parse(json['ticket_verification_date'])
          : null,
      status: TripStatus.fromString(json['status'] ?? 'draft'),
      viewCount: json['view_count'] ?? 0,
      bookingCount: json['booking_count'] ?? 0,
      description: json['description'],
      specialNotes: json['special_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? TripUser.fromJson(json['user']) : null,
      restrictedCategories: json['restricted_categories'] != null
          ? List<String>.from(json['restricted_categories'])
          : null,
      restrictedItems: json['restricted_items'] != null
          ? List<String>.from(json['restricted_items'])
          : null,
      restrictionNotes: json['restriction_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'user_id': userId,
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
      'description': description,
      'special_notes': specialNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
      if (restrictedCategories != null) 'restricted_categories': restrictedCategories,
      if (restrictedItems != null) 'restricted_items': restrictedItems,
      if (restrictionNotes != null) 'restriction_notes': restrictionNotes,
    };
  }

  Trip copyWith({
    String? id,
    String? uuid,
    String? userId,
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
    String? description,
    String? specialNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    TripUser? user,
    List<String>? restrictedCategories,
    List<String>? restrictedItems,
    String? restrictionNotes,
  }) {
    return Trip(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      transportType: this.transportType,
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
      description: description ?? this.description,
      specialNotes: specialNotes ?? this.specialNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      restrictedCategories: restrictedCategories ?? this.restrictedCategories,
      restrictedItems: restrictedItems ?? this.restrictedItems,
      restrictionNotes: restrictionNotes ?? this.restrictionNotes,
    );
  }

  // Business logic methods
  bool get isEditable => 
    (status == TripStatus.draft || status == TripStatus.published || status == TripStatus.rejected) &&
    departureDate.isAfter(DateTime.now());

  bool get canBePublished => 
    (status == TripStatus.draft || status == TripStatus.rejected) &&
    departureDate.isAfter(DateTime.now());

  bool get isPendingApproval => status == TripStatus.pendingApproval;
  bool get isRejected => status == TripStatus.rejected;
  bool get isFlaggedForReview => status == TripStatus.flaggedForReview;

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
}

enum TripStatus {
  draft('draft'),
  pendingApproval('pending_approval'),
  published('published'),
  rejected('rejected'),
  flaggedForReview('flagged_for_review'),
  completed('completed'),
  cancelled('cancelled');

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
      case TripStatus.pendingApproval:
        return 'En attente d\'approbation';
      case TripStatus.published:
        return 'Publié';
      case TripStatus.rejected:
        return 'Rejeté';
      case TripStatus.flaggedForReview:
        return 'Signalé pour révision';
      case TripStatus.completed:
        return 'Terminé';
      case TripStatus.cancelled:
        return 'Annulé';
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
      isVerified: json['is_verified'] ?? false,
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
      distanceKm: json['distance_km'] ?? 0,
      basePricePerKg: (json['base_price_per_kg'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 15.0,
      suggestedPricePerKg: (json['suggested_price_per_kg'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'CAD',
      exchangeRates: Map<String, double>.from(json['exchange_rates'] ?? {}),
    );
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