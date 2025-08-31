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
        
      case TransportType.flight:
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
    bool result = country == 'CA' || country == 'Canada';
    print('DEBUG: _isCanada("$country") = $result');
    print('DEBUG: country codeUnits: ${country.codeUnits}');
    return result;
  }

  /// Gets allowed countries for a transport type
  static List<Map<String, String>> getAllowedCountries(TransportType transportType) {
    switch (transportType) {
      case TransportType.car:
        // Car: only Canada
        return LocationsData.countries.where((country) => country['value'] == 'CA').toList();
        
      case TransportType.flight:
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
        
      case TransportType.flight:
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
    print('=== DEBUG: validateRoute() START ===');
    print('DEBUG: transportType: ${transportType.value}');
    print('DEBUG: departureCity: "$departureCity"');
    print('DEBUG: departureCountry: "$departureCountry"');
    print('DEBUG: arrivalCity: "$arrivalCity"');
    print('DEBUG: arrivalCountry: "$arrivalCountry"');
    print('DEBUG: departureCountry.runtimeType: ${departureCountry.runtimeType}');
    print('DEBUG: arrivalCountry.runtimeType: ${arrivalCountry.runtimeType}');
    print('DEBUG: departureCountry.length: ${departureCountry.length}');
    print('DEBUG: arrivalCountry.length: ${arrivalCountry.length}');
    print('DEBUG: departureCountry codeUnits: ${departureCountry.codeUnits}');
    print('DEBUG: arrivalCountry codeUnits: ${arrivalCountry.codeUnits}');
    print('DEBUG: _isCanada(departureCountry): ${_isCanada(departureCountry)}');
    print('DEBUG: _isCanada(arrivalCountry): ${_isCanada(arrivalCountry)}');
    print('DEBUG: departureCountry == "Canada": ${departureCountry == "Canada"}');
    print('DEBUG: arrivalCountry == "Canada": ${arrivalCountry == "Canada"}');
    print('DEBUG: departureCountry == "CA": ${departureCountry == "CA"}');
    print('DEBUG: arrivalCountry == "CA": ${arrivalCountry == "CA"}');
    
    if (departureCountry == arrivalCountry && departureCity == arrivalCity) {
      print('DEBUG: Same city error');
      return 'La ville de départ et d\'arrivée ne peuvent pas être identiques';
    }

    switch (transportType) {
      case TransportType.car:
        if (!_isCanada(departureCountry)) {
          print('DEBUG: Departure country not Canada - VALIDATION FAILED');
          return 'Les voyages en voiture ne sont autorisés qu\'au Canada. Veuillez choisir une ville canadienne de départ.';
        }
        if (!_isCanada(arrivalCountry)) {
          print('DEBUG: Arrival country not Canada - VALIDATION FAILED');
          return 'Les voyages en voiture ne sont autorisés qu\'au Canada. Veuillez choisir une ville canadienne d\'arrivée.';
        }
        print('DEBUG: Car route validation PASSED - both cities are Canadian');
        break;
        
      case TransportType.flight:
        if (!_includesCanada(departureCountry, arrivalCountry)) {
          return 'Les vols doivent inclure le Canada. Au moins une destination (départ ou arrivée) doit être au Canada.';
        }
        break;
    }

    print('=== DEBUG: validateRoute() END - ROUTE IS VALID ===');
    return null; // Route is valid
  }

  /// Gets user-friendly description of transport restrictions
  static String getTransportRestrictions(TransportType transportType) {
    switch (transportType) {
      case TransportType.car:
        return 'Voyages en voiture : uniquement entre les villes canadiennes';
        
      case TransportType.flight:
        return 'Vols : Canada ↔ International ou Canada ↔ Canada (pas International ↔ International)';
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