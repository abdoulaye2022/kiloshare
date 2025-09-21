class SearchParams {
  final String? departureCity;
  final String? arrivalCity;
  final String? departureCountry;
  final String? arrivalCountry;
  final String? departureDate;
  final double? maxPrice;
  final int? minWeight;
  final String? transportType;
  final double? minRating;
  final bool verifiedOnly;
  final String? sortBy;

  const SearchParams({
    this.departureCity,
    this.arrivalCity,
    this.departureCountry,
    this.arrivalCountry,
    this.departureDate,
    this.maxPrice,
    this.minWeight,
    this.transportType,
    this.minRating,
    this.verifiedOnly = false,
    this.sortBy,
  });

  factory SearchParams.fromJson(Map<String, dynamic> json) => SearchParams(
    departureCity: json['departure_city'] as String?,
    arrivalCity: json['arrival_city'] as String?,
    departureCountry: json['departure_country'] as String?,
    arrivalCountry: json['arrival_country'] as String?,
    departureDate: json['departure_date'] as String?,
    maxPrice: json['max_price']?.toDouble(),
    minWeight: json['min_weight'] as int?,
    transportType: json['transport_type'] as String?,
    minRating: json['min_rating']?.toDouble(),
    verifiedOnly: json['verified_only'] as bool? ?? false,
    sortBy: json['sort_by'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (departureCity != null) 'departure_city': departureCity!,
    if (arrivalCity != null) 'arrival_city': arrivalCity!,
    if (departureCountry != null) 'departure_country': departureCountry!,
    if (arrivalCountry != null) 'arrival_country': arrivalCountry!,
    if (departureDate != null) 'departure_date': departureDate!,
    if (maxPrice != null) 'max_price': maxPrice!,
    if (minWeight != null) 'min_weight': minWeight!,
    if (transportType != null) 'transport_type': transportType!,
    if (minRating != null) 'min_rating': minRating!,
    'verified_only': verifiedOnly,
    if (sortBy != null) 'sort_by': sortBy!,
  };

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    
    if (departureCity != null) params['departure_city'] = departureCity!;
    if (arrivalCity != null) params['arrival_city'] = arrivalCity!;
    if (departureCountry != null) params['departure_country'] = departureCountry!;
    if (arrivalCountry != null) params['arrival_country'] = arrivalCountry!;
    if (departureDate != null) params['departure_date'] = departureDate!;
    if (maxPrice != null) params['max_price'] = maxPrice!.toString();
    if (minWeight != null) params['min_weight'] = minWeight!.toString();
    if (transportType != null) params['transport_type'] = transportType!;
    if (minRating != null) params['min_rating'] = minRating!.toString();
    if (verifiedOnly) params['verified_only'] = 'true';
    if (sortBy != null) params['sort_by'] = sortBy!;
    
    return params;
  }

  SearchParams copyWith({
    String? departureCity,
    String? arrivalCity,
    String? departureCountry,
    String? arrivalCountry,
    String? departureDate,
    double? maxPrice,
    int? minWeight,
    String? transportType,
    double? minRating,
    bool? verifiedOnly,
    String? sortBy,
  }) {
    return SearchParams(
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureCountry: departureCountry ?? this.departureCountry,
      arrivalCountry: arrivalCountry ?? this.arrivalCountry,
      departureDate: departureDate ?? this.departureDate,
      maxPrice: maxPrice ?? this.maxPrice,
      minWeight: minWeight ?? this.minWeight,
      transportType: transportType ?? this.transportType,
      minRating: minRating ?? this.minRating,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get isEmpty =>
      departureCity == null &&
      arrivalCity == null &&
      departureDate == null &&
      maxPrice == null &&
      minWeight == null &&
      transportType == null &&
      minRating == null &&
      !verifiedOnly;

  String get searchSummary {
    final parts = <String>[];
    
    if (departureCity != null && arrivalCity != null) {
      parts.add('$departureCity → $arrivalCity');
    }
    
    if (departureDate != null) {
      parts.add('Départ: $departureDate');
    }
    
    if (maxPrice != null) {
      parts.add('Max: \$${maxPrice!.toStringAsFixed(2)}');
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchParams &&
        other.departureCity == departureCity &&
        other.arrivalCity == arrivalCity &&
        other.departureCountry == departureCountry &&
        other.arrivalCountry == arrivalCountry &&
        other.departureDate == departureDate &&
        other.maxPrice == maxPrice &&
        other.minWeight == minWeight &&
        other.transportType == transportType &&
        other.minRating == minRating &&
        other.verifiedOnly == verifiedOnly &&
        other.sortBy == sortBy;
  }

  @override
  int get hashCode {
    return Object.hash(
      departureCity,
      arrivalCity,
      departureCountry,
      arrivalCountry,
      departureDate,
      maxPrice,
      minWeight,
      transportType,
      minRating,
      verifiedOnly,
      sortBy,
    );
  }

  @override
  String toString() {
    return 'SearchParams(departureCity: $departureCity, arrivalCity: $arrivalCity, '
        'departureDate: $departureDate, transportType: $transportType)';
  }
}