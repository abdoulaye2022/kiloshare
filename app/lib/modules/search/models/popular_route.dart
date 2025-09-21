class PopularRoute {
  final int? id;
  final String departureCity;
  final String departureCountry;
  final String arrivalCity;
  final String arrivalCountry;
  final int searchCount;
  final DateTime? lastSearched;
  final DateTime? createdAt;
  final String? routeDisplay;
  final String? popularityLevel;

  const PopularRoute({
    this.id,
    required this.departureCity,
    this.departureCountry = 'Canada',
    required this.arrivalCity,
    this.arrivalCountry = 'Canada',
    this.searchCount = 1,
    this.lastSearched,
    this.createdAt,
    this.routeDisplay,
    this.popularityLevel,
  });

  factory PopularRoute.fromJson(Map<String, dynamic> json) => PopularRoute(
    id: json['id'] as int?,
    departureCity: json['departure_city'] as String,
    departureCountry: json['departure_country'] as String? ?? 'Canada',
    arrivalCity: json['arrival_city'] as String,
    arrivalCountry: json['arrival_country'] as String? ?? 'Canada',
    searchCount: json['search_count'] as int? ?? 1,
    lastSearched: json['last_searched'] != null ? DateTime.parse(json['last_searched'] as String) : null,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    routeDisplay: json['route_display'] as String?,
    popularityLevel: json['popularity_level'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id!,
    'departure_city': departureCity,
    'departure_country': departureCountry,
    'arrival_city': arrivalCity,
    'arrival_country': arrivalCountry,
    'search_count': searchCount,
    if (lastSearched != null) 'last_searched': lastSearched!.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (routeDisplay != null) 'route_display': routeDisplay!,
    if (popularityLevel != null) 'popularity_level': popularityLevel!,
  };

  String get displayRoute {
    if (routeDisplay != null) return routeDisplay!;
    
    final from = departureCountry != 'Canada' ? '$departureCity, $departureCountry' : departureCity;
    final to = arrivalCountry != 'Canada' ? '$arrivalCity, $arrivalCountry' : arrivalCity;
    return '$from → $to';
  }

  String get popularityLevelText {
    if (popularityLevel != null) return popularityLevel!;
    
    if (searchCount >= 100) return 'très populaire';
    if (searchCount >= 50) return 'populaire';
    if (searchCount >= 20) return 'modéré';
    if (searchCount >= 10) return 'émergent';
    return 'nouveau';
  }

  int get popularityScore => (searchCount * 100 / 100).clamp(0, 100).toInt();

  bool get isTrending {
    if (lastSearched == null) return false;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return lastSearched!.isAfter(weekAgo) && searchCount >= 5;
  }

  String get routeKey {
    return '${departureCity.toLowerCase()}_${departureCountry.toLowerCase()}_to_${arrivalCity.toLowerCase()}_${arrivalCountry.toLowerCase()}';
  }

  String get trendingStatus {
    if (isTrending) return '🔥 Tendance';
    if (searchCount >= 50) return '⭐ Populaire';
    if (searchCount >= 20) return '👀 Recherché';
    return '';
  }

  PopularRoute copyWith({
    int? id,
    String? departureCity,
    String? departureCountry,
    String? arrivalCity,
    String? arrivalCountry,
    int? searchCount,
    DateTime? lastSearched,
    DateTime? createdAt,
    String? routeDisplay,
    String? popularityLevel,
  }) {
    return PopularRoute(
      id: id ?? this.id,
      departureCity: departureCity ?? this.departureCity,
      departureCountry: departureCountry ?? this.departureCountry,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      arrivalCountry: arrivalCountry ?? this.arrivalCountry,
      searchCount: searchCount ?? this.searchCount,
      lastSearched: lastSearched ?? this.lastSearched,
      createdAt: createdAt ?? this.createdAt,
      routeDisplay: routeDisplay ?? this.routeDisplay,
      popularityLevel: popularityLevel ?? this.popularityLevel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PopularRoute &&
        other.departureCity == departureCity &&
        other.departureCountry == departureCountry &&
        other.arrivalCity == arrivalCity &&
        other.arrivalCountry == arrivalCountry;
  }

  @override
  int get hashCode {
    return Object.hash(departureCity, departureCountry, arrivalCity, arrivalCountry);
  }

  @override
  String toString() {
    return 'PopularRoute(route: $displayRoute, searchCount: $searchCount, level: $popularityLevelText)';
  }
}