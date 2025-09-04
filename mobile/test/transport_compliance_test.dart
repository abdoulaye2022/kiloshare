import 'package:flutter_test/flutter_test.dart';
import 'package:kiloshare/modules/trips/models/transport_models.dart';
import 'package:kiloshare/modules/trips/services/multi_transport_service.dart';
import 'package:kiloshare/modules/trips/services/destination_validator_service.dart';

void main() {
  group('Transport Compliance Rules', () {
    late MultiTransportService multiTransportService;

    setUp(() {
      multiTransportService = MultiTransportService();
    });

    group('Weight Limits', () {
      test('Car should have 200kg limit', () {
        final limit = multiTransportService.getWeightLimit(TransportType.car);
        expect(limit, 200.0);
      });

      test('Plane should have 23kg limit', () {
        final limit = multiTransportService.getWeightLimit(TransportType.plane);
        expect(limit, 23.0);
      });
    });

    group('Destination Validation - Car Transport', () {
      test('Canada to Canada should be valid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.car,
          departureCity: 'Toronto',
          departureCountry: 'Canada',
          arrivalCity: 'Montreal',
          arrivalCountry: 'Canada',
        );
        expect(result, isNull); // No error = valid
      });

      test('Canada to International should be invalid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.car,
          departureCity: 'Toronto',
          departureCountry: 'Canada',
          arrivalCity: 'Paris',
          arrivalCountry: 'France',
        );
        expect(result, isNotNull); // Error = invalid
        expect(result, contains('voiture ne sont autorisés qu\'au Canada'));
      });

      test('International to Canada should be invalid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.car,
          departureCity: 'Paris',
          departureCountry: 'France',
          arrivalCity: 'Montreal',
          arrivalCountry: 'Canada',
        );
        expect(result, isNotNull); // Error = invalid
        expect(result, contains('voiture ne sont autorisés qu\'au Canada'));
      });
    });

    group('Destination Validation - Plane Transport', () {
      test('Canada to Canada should be valid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.plane,
          departureCity: 'Toronto',
          departureCountry: 'Canada',
          arrivalCity: 'Montreal',
          arrivalCountry: 'Canada',
        );
        expect(result, isNull); // No error = valid
      });

      test('Canada to International should be valid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.plane,
          departureCity: 'Montreal',
          departureCountry: 'Canada',
          arrivalCity: 'Paris',
          arrivalCountry: 'France',
        );
        expect(result, isNull); // No error = valid
      });

      test('International to Canada should be valid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.plane,
          departureCity: 'Paris',
          departureCountry: 'France',
          arrivalCity: 'Montreal',
          arrivalCountry: 'Canada',
        );
        expect(result, isNull); // No error = valid
      });

      test('International to International should be invalid (Paris → London)', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.plane,
          departureCity: 'Paris',
          departureCountry: 'France',
          arrivalCity: 'London',
          arrivalCountry: 'United Kingdom',
        );
        expect(result, isNotNull); // Error = invalid
        expect(result, contains('doivent inclure le Canada'));
        expect(result, contains('Paris → Londres ne sont pas autorisés'));
      });
    });

    group('Transport Restrictions Display', () {
      test('Car restrictions should mention 200kg and Canada only', () {
        final restrictions = DestinationValidatorService.getTransportRestrictions(
          TransportType.car,
        );
        expect(restrictions, contains('200kg'));
        expect(restrictions, contains('canadiennes'));
        expect(restrictions, contains('🚗'));
      });

      test('Plane restrictions should mention 23kg and Canada requirement', () {
        final restrictions = DestinationValidatorService.getTransportRestrictions(
          TransportType.plane,
        );
        expect(restrictions, contains('23kg'));
        expect(restrictions, contains('Canada'));
        expect(restrictions, contains('✈️'));
        expect(restrictions, contains('Paris → Londres'));
      });
    });

    group('Edge Cases', () {
      test('Same city departure and arrival should be invalid', () {
        final result = DestinationValidatorService.validateRoute(
          transportType: TransportType.car,
          departureCity: 'Toronto',
          departureCountry: 'Canada',
          arrivalCity: 'Toronto',
          arrivalCountry: 'Canada',
        );
        expect(result, isNotNull);
        expect(result, contains('ne peuvent pas être identiques'));
      });
    });
  });
}