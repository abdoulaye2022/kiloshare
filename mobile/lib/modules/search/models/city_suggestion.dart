class CitySuggestion {
  final String cityName;
  final String country;
  final int searchCount;
  final bool isPopular;

  const CitySuggestion({
    required this.cityName,
    required this.country,
    this.searchCount = 0,
    this.isPopular = false,
  });

  factory CitySuggestion.fromJson(Map<String, dynamic> json) => CitySuggestion(
    cityName: json['city_name'] as String,
    country: json['country'] as String? ?? 'Canada',
    searchCount: json['search_count'] as int? ?? 0,
    isPopular: json['is_popular'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'city_name': cityName,
    'country': country,
    'search_count': searchCount,
    'is_popular': isPopular,
  };

  String get displayName {
    if (country != 'Canada') {
      return '$cityName, $country';
    }
    return cityName;
  }

  String get fullName => '$cityName, $country';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CitySuggestion &&
        other.cityName == cityName &&
        other.country == country;
  }

  @override
  int get hashCode => cityName.hashCode ^ country.hashCode;

  @override
  String toString() {
    return 'CitySuggestion(cityName: $cityName, country: $country, isPopular: $isPopular)';
  }
}