class SearchAlert {
  final int? id;
  final int? userId;
  final String departureCity;
  final String departureCountry;
  final String arrivalCity;
  final String arrivalCountry;
  final String? dateRangeStart;
  final String? dateRangeEnd;
  final double? maxPrice;
  final int? maxWeight;
  final String? transportType;
  final double? minRating;
  final bool verifiedOnly;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SearchAlert({
    this.id,
    this.userId,
    required this.departureCity,
    this.departureCountry = 'Canada',
    required this.arrivalCity,
    this.arrivalCountry = 'Canada',
    this.dateRangeStart,
    this.dateRangeEnd,
    this.maxPrice,
    this.maxWeight,
    this.transportType,
    this.minRating,
    this.verifiedOnly = false,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory SearchAlert.fromJson(Map<String, dynamic> json) => SearchAlert(
    id: json['id'] as int?,
    userId: json['user_id'] as int?,
    departureCity: json['departure_city'] as String,
    departureCountry: json['departure_country'] as String? ?? 'Canada',
    arrivalCity: json['arrival_city'] as String,
    arrivalCountry: json['arrival_country'] as String? ?? 'Canada',
    dateRangeStart: json['date_range_start'] as String?,
    dateRangeEnd: json['date_range_end'] as String?,
    maxPrice: json['max_price']?.toDouble(),
    maxWeight: json['max_weight'] as int?,
    transportType: json['transport_type'] as String?,
    minRating: json['min_rating']?.toDouble(),
    verifiedOnly: json['verified_only'] as bool? ?? false,
    active: json['active'] as bool? ?? true,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id!,
    if (userId != null) 'user_id': userId!,
    'departure_city': departureCity,
    'departure_country': departureCountry,
    'arrival_city': arrivalCity,
    'arrival_country': arrivalCountry,
    if (dateRangeStart != null) 'date_range_start': dateRangeStart!,
    if (dateRangeEnd != null) 'date_range_end': dateRangeEnd!,
    if (maxPrice != null) 'max_price': maxPrice!,
    if (maxWeight != null) 'max_weight': maxWeight!,
    if (transportType != null) 'transport_type': transportType!,
    if (minRating != null) 'min_rating': minRating!,
    'verified_only': verifiedOnly,
    'active': active,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  String get routeDisplay {
    final from = departureCountry != 'Canada' ? '$departureCity, $departureCountry' : departureCity;
    final to = arrivalCountry != 'Canada' ? '$arrivalCity, $arrivalCountry' : arrivalCity;
    return '$from → $to';
  }

  String get alertSummary {
    final parts = <String>[routeDisplay];
    
    if (dateRangeStart != null) {
      final startDate = DateTime.parse(dateRangeStart!);
      parts.add('À partir du ${_formatDate(startDate)}');
    }
    
    if (maxPrice != null) {
      parts.add('Max \$${maxPrice!.toStringAsFixed(2)}/kg');
    }
    
    if (transportType != null) {
      final transportEmojis = {
        'plane': '✈️',
        'car': '🚗',
        'bus': '🚌',
        'train': '🚆',
      };
      parts.add(transportEmojis[transportType] ?? transportType!);
    }
    
    return parts.join(' • ');
  }

  String _formatDate(DateTime date) {
    final months = [
      'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  SearchAlert copyWith({
    int? id,
    int? userId,
    String? departureCity,
    String? departureCountry,
    String? arrivalCity,
    String? arrivalCountry,
    String? dateRangeStart,
    String? dateRangeEnd,
    double? maxPrice,
    int? maxWeight,
    String? transportType,
    double? minRating,
    bool? verifiedOnly,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SearchAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      departureCity: departureCity ?? this.departureCity,
      departureCountry: departureCountry ?? this.departureCountry,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      arrivalCountry: arrivalCountry ?? this.arrivalCountry,
      dateRangeStart: dateRangeStart ?? this.dateRangeStart,
      dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
      maxPrice: maxPrice ?? this.maxPrice,
      maxWeight: maxWeight ?? this.maxWeight,
      transportType: transportType ?? this.transportType,
      minRating: minRating ?? this.minRating,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchAlert &&
        other.id == id &&
        other.departureCity == departureCity &&
        other.arrivalCity == arrivalCity &&
        other.departureCountry == departureCountry &&
        other.arrivalCountry == arrivalCountry;
  }

  @override
  int get hashCode {
    return Object.hash(id, departureCity, arrivalCity, departureCountry, arrivalCountry);
  }

  @override
  String toString() {
    return 'SearchAlert(id: $id, route: $routeDisplay, active: $active)';
  }
}