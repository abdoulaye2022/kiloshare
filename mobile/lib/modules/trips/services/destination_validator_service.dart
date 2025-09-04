import '../models/transport_models.dart';
import '../../../data/locations_data.dart';

class DestinationValidatorService {
  /// Validates if a destination is allowed for the given transport type
  static bool isDestinationValid({
    required TransportType transportType,
    required String departureCity,
    required String departureCountry,
    required String arrivalCity,
    required String arrivalCountry,
  }) {
    switch (transportType) {
      case TransportType.car:
        // Car: only within Canada
        return _isBothCanada(departureCountry, arrivalCountry);
        
      case TransportType.plane:
        // Flight: at least one destination must be Canada (no foreign to foreign)
        return _includesCanada(departureCountry, arrivalCountry);
    }
  }

  /// Checks if both countries are Canada
  static bool _isBothCanada(String departureCountry, String arrivalCountry) {
    return _isCanada(departureCountry) && _isCanada(arrivalCountry);
  }

  /// Checks if at least one country is Canada
  static bool _includesCanada(String departureCountry, String arrivalCountry) {
    return _isCanada(departureCountry) || _isCanada(arrivalCountry);
  }

  /// Checks if a country is Canada
  static bool _isCanada(String country) {
    return country == 'CA' || country == 'Canada';
  }

  /// Gets allowed countries for a transport type
  static List<Map<String, String>> getAllowedCountries(TransportType transportType) {
    switch (transportType) {
      case TransportType.car:
        // Car: only Canada
        return LocationsData.countries.where((country) => country['value'] == 'CA').toList();
        
      case TransportType.plane:
        // Flight: all countries (but with Canada restriction)
        return LocationsData.countries;
    }
  }

  /// Gets allowed cities for a transport type and selected country
  static List<Map<String, String>> getAllowedCities({
    required TransportType transportType,
    required String countryCode,
  }) {
    switch (transportType) {
      case TransportType.car:
        // Car: only Canadian cities
        if (countryCode == 'CA') {
          return LocationsData.getCitiesForCountry('CA');
        }
        return [];
        
      case TransportType.plane:
        // Flight: cities from any country
        return LocationsData.getCitiesForCountry(countryCode);
    }
  }

  /// Validates a route and returns error message if invalid
  static String? validateRoute({
    required TransportType transportType,
    required String departureCity,
    required String departureCountry,
    required String arrivalCity,
    required String arrivalCountry,
  }) {
    
    if (departureCountry == arrivalCountry && departureCity == arrivalCity) {
      return 'La ville de départ et d\'arrivée ne peuvent pas être identiques';
    }

    switch (transportType) {
      case TransportType.car:
        if (!_isCanada(departureCountry)) {
          return 'Les voyages en voiture ne sont autorisés qu\'au Canada. Veuillez choisir une ville canadienne de départ.';
        }
        if (!_isCanada(arrivalCountry)) {
          return 'Les voyages en voiture ne sont autorisés qu\'au Canada. Veuillez choisir une ville canadienne d\'arrivée.';
        }
        break;
        
      case TransportType.plane:
        if (!_includesCanada(departureCountry, arrivalCountry)) {
          return 'Les vols doivent inclure le Canada. Les trajets comme Paris → Londres ne sont pas autorisés. Exemples valides: Montréal → Paris, Toronto → Londres, Paris → Vancouver.';
        }
        break;
    }

    return null; // Route is valid
  }

  /// Gets user-friendly description of transport restrictions
  static String getTransportRestrictions(TransportType transportType) {
    switch (transportType) {
      case TransportType.car:
        return '🚗 Voiture (200kg max) : Uniquement entre les villes canadiennes\nExemples: Toronto → Montréal, Vancouver → Calgary';
        
      case TransportType.plane:
        return '✈️ Avion (23kg max) : Canada ↔ International ou Canada ↔ Canada\nValide: Montréal → Paris, Toronto → Londres\nInterdit: Paris → Londres';
    }
  }

  /// Gets Canadian provinces that are most relevant for transport
  static List<Map<String, String>> getCanadianProvinces() {
    return LocationsData.provinces;
  }

  /// Gets Canadian cities for car transport (all Canadian cities)
  static List<Map<String, String>> getCanadianCities() {
    return LocationsData.getCitiesForCountry('CA');
  }

  /// Gets international cities for flight transport (non-Canadian cities)
  static List<Map<String, String>> getInternationalCities() {
    final allCities = <Map<String, String>>[];
    
    for (final country in LocationsData.countries) {
      if (country['value'] != 'CA') {
        allCities.addAll(LocationsData.getCitiesForCountry(country['value']!));
      }
    }
    
    return allCities;
  }
}