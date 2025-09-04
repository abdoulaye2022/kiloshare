enum TransportType {
  plane('plane', 'Avion', 'Rapide et sécurisé - International et domestique'),
  car('car', 'Voiture', 'Flexible et grande capacité - Canada seulement');

  const TransportType(this.value, this.displayName, this.description);
  
  final String value;
  final String displayName;
  final String description;
  
  static TransportType fromString(String value) {
    return TransportType.values.firstWhere((e) => e.value == value);
  }
}

class TransportLimit {
  final TransportType type;
  final String name;
  final double maxWeightKg;
  final double baseRatePerKg;
  final double commissionRate;
  final TransportFeatures features;

  TransportLimit({
    required this.type,
    required this.name,
    required this.maxWeightKg,
    required this.baseRatePerKg,
    required this.commissionRate,
    required this.features,
  });

  factory TransportLimit.fromJson(Map<String, dynamic> json) {
    return TransportLimit(
      type: TransportType.fromString(json['type']),
      name: json['name'],
      maxWeightKg: json['max_weight_kg'].toDouble(),
      baseRatePerKg: json['base_rate_per_kg'].toDouble(),
      commissionRate: json['commission_rate'].toDouble(),
      features: TransportFeatures.fromJson(json['features']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'name': name,
      'max_weight_kg': maxWeightKg,
      'base_rate_per_kg': baseRatePerKg,
      'commission_rate': commissionRate,
      'features': features.toJson(),
    };
  }
}

class TransportFeatures {
  final bool flexibleDeparture;
  final bool intermediateStops;
  final bool vehicleInfoRequired;
  final bool flightInfoRequired;
  final bool ticketValidationSupported;

  TransportFeatures({
    required this.flexibleDeparture,
    required this.intermediateStops,
    required this.vehicleInfoRequired,
    required this.flightInfoRequired,
    required this.ticketValidationSupported,
  });

  factory TransportFeatures.fromJson(Map<String, dynamic> json) {
    return TransportFeatures(
      flexibleDeparture: json['flexible_departure'] ?? false,
      intermediateStops: json['intermediate_stops'] ?? false,
      vehicleInfoRequired: json['vehicle_info_required'] ?? false,
      flightInfoRequired: json['flight_info_required'] ?? false,
      ticketValidationSupported: json['ticket_validation_supported'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flexible_departure': flexibleDeparture,
      'intermediate_stops': intermediateStops,
      'vehicle_info_required': vehicleInfoRequired,
      'flight_info_required': flightInfoRequired,
      'ticket_validation_supported': ticketValidationSupported,
    };
  }
}

class MultiTransportPriceSuggestion {
  final double suggestedPricePerKg;
  final double totalPrice;
  final double commission;
  final double netEarnings;
  final String currency;
  final TransportType transportType;
  final int distanceKm;
  final double weightKg;
  final double baseRate;
  final double commissionRate;
  final String explanation;

  MultiTransportPriceSuggestion({
    required this.suggestedPricePerKg,
    required this.totalPrice,
    required this.commission,
    required this.netEarnings,
    required this.currency,
    required this.transportType,
    required this.distanceKm,
    required this.weightKg,
    required this.baseRate,
    required this.commissionRate,
    required this.explanation,
  });

  factory MultiTransportPriceSuggestion.fromJson(Map<String, dynamic> json) {
    return MultiTransportPriceSuggestion(
      suggestedPricePerKg: json['suggested_price_per_kg'].toDouble(),
      totalPrice: json['total_price'].toDouble(),
      commission: json['commission'].toDouble(),
      netEarnings: json['net_earnings'].toDouble(),
      currency: json['currency'],
      transportType: TransportType.fromString(json['transport_type']),
      distanceKm: json['distance_km'],
      weightKg: json['weight_kg'].toDouble(),
      baseRate: json['base_rate'].toDouble(),
      commissionRate: json['commission_rate'].toDouble(),
      explanation: json['explanation'],
    );
  }
}

class TransportRecommendation {
  final TransportType transportType;
  final String name;
  final double pricePerKg;
  final double totalPrice;
  final double netEarnings;
  final int suitabilityScore;
  final List<String> pros;
  final List<String> cons;

  TransportRecommendation({
    required this.transportType,
    required this.name,
    required this.pricePerKg,
    required this.totalPrice,
    required this.netEarnings,
    required this.suitabilityScore,
    required this.pros,
    required this.cons,
  });

  factory TransportRecommendation.fromJson(Map<String, dynamic> json) {
    return TransportRecommendation(
      transportType: TransportType.fromString(json['transport_type']),
      name: json['name'],
      pricePerKg: json['price_per_kg'].toDouble(),
      totalPrice: json['total_price'].toDouble(),
      netEarnings: json['net_earnings'].toDouble(),
      suitabilityScore: json['suitability_score'],
      pros: List<String>.from(json['pros']),
      cons: List<String>.from(json['cons']),
    );
  }
}

class VehicleInfo {
  final String make;
  final String model;
  final String licensePlate;
  final String? year;
  final String? color;
  final bool verified;
  final DateTime? verificationDate;

  VehicleInfo({
    required this.make,
    required this.model,
    required this.licensePlate,
    this.year,
    this.color,
    this.verified = false,
    this.verificationDate,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      make: json['vehicle_make'],
      model: json['vehicle_model'],
      licensePlate: json['license_plate'],
      year: json['vehicle_year'],
      color: json['vehicle_color'],
      verified: json['vehicle_verified'] ?? false,
      verificationDate: json['vehicle_verification_date'] != null
          ? DateTime.parse(json['vehicle_verification_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'license_plate': licensePlate,
      'year': year,
      'color': color,
      'verified': verified,
      'verification_date': verificationDate?.toIso8601String(),
    };
  }
}

class FlightInfo {
  final String flightNumber;
  final String airline;
  final bool verified;
  final DateTime? verificationDate;

  FlightInfo({
    required this.flightNumber,
    required this.airline,
    this.verified = false,
    this.verificationDate,
  });

  factory FlightInfo.fromJson(Map<String, dynamic> json) {
    return FlightInfo(
      flightNumber: json['flight_number'],
      airline: json['airline'],
      verified: json['flight_verified'] ?? false,
      verificationDate: json['flight_verification_date'] != null
          ? DateTime.parse(json['flight_verification_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flight_number': flightNumber,
      'airline': airline,
      'verified': verified,
      'verification_date': verificationDate?.toIso8601String(),
    };
  }
}