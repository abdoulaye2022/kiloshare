import 'package:flutter_test/flutter_test.dart';
import '../lib/modules/trips/models/trip_model.dart';
import '../lib/modules/trips/services/trip_state_manager.dart';

void main() {
  group('TripStateManager', () {
    late Trip testTrip;

    setUp(() {
      testTrip = Trip(
        id: '1',
        uuid: 'test-uuid',
        userId: 'user-1',
        transportType: 'flight',
        departureCity: 'Montreal',
        departureCountry: 'Canada',
        departureDate: DateTime.now().add(const Duration(days: 7)),
        arrivalCity: 'Paris',
        arrivalCountry: 'France',
        arrivalDate: DateTime.now().add(const Duration(days: 8)),
        availableWeightKg: 20.0,
        pricePerKg: 15.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: TripStatus.draft,
      );
    });

    test('should allow transition from draft to pending review', () {
      expect(
        TripStateManager.canTransitionTo(TripStatus.draft, TripStatus.pendingReview),
        isTrue,
      );
    });

    test('should allow transition from draft to active', () {
      expect(
        TripStateManager.canTransitionTo(TripStatus.draft, TripStatus.active),
        isTrue,
      );
    });

    test('should not allow transition from completed to active', () {
      expect(
        TripStateManager.canTransitionTo(TripStatus.completed, TripStatus.active),
        isFalse,
      );
    });

    test('should return correct available actions for draft status', () {
      final actions = TripStateManager.getAvailableActions(TripStatus.draft);
      expect(actions, contains(TripAction.publish));
      expect(actions, contains(TripAction.edit));
      expect(actions, contains(TripAction.delete));
      expect(actions, contains(TripAction.duplicate));
    });

    test('should return correct available actions for active status', () {
      final actions = TripStateManager.getAvailableActions(TripStatus.active);
      expect(actions, contains(TripAction.pause));
      expect(actions, contains(TripAction.edit));
      expect(actions, contains(TripAction.cancel));
      expect(actions, contains(TripAction.share));
      expect(actions, contains(TripAction.viewAnalytics));
    });

    test('should allow publish action for draft trip', () {
      expect(
        TripStateManager.canPerformAction(testTrip, TripAction.publish),
        isTrue,
      );
    });

    test('should not allow pause action for draft trip', () {
      expect(
        TripStateManager.canPerformAction(testTrip, TripAction.pause),
        isFalse,
      );
    });

    test('should identify final states correctly', () {
      expect(TripStateManager.isFinalState(TripStatus.completed), isTrue);
      expect(TripStateManager.isFinalState(TripStatus.cancelled), isTrue);
      expect(TripStateManager.isFinalState(TripStatus.expired), isTrue);
      expect(TripStateManager.isFinalState(TripStatus.active), isFalse);
    });

    test('should identify trips requiring attention', () {
      final rejectedTrip = testTrip.copyWith(status: TripStatus.rejected);
      expect(TripStateManager.requiresAttention(rejectedTrip), isTrue);
      
      final pendingTrip = testTrip.copyWith(status: TripStatus.pendingReview);
      expect(TripStateManager.requiresAttention(pendingTrip), isTrue);
      
      final activeTrip = testTrip.copyWith(status: TripStatus.active);
      expect(TripStateManager.requiresAttention(activeTrip), isFalse);
    });

    test('should return correct priority levels', () {
      final urgentTrip = testTrip.copyWith(isUrgent: true);
      expect(TripStateManager.getPriority(urgentTrip), equals(TripPriority.high));
      
      final featuredTrip = testTrip.copyWith(isFeatured: true);
      expect(TripStateManager.getPriority(featuredTrip), equals(TripPriority.high));
      
      final rejectedTrip = testTrip.copyWith(status: TripStatus.rejected);
      expect(TripStateManager.getPriority(rejectedTrip), equals(TripPriority.medium));
      
      final normalTrip = testTrip.copyWith(
        status: TripStatus.active,
        departureDate: DateTime.now().add(const Duration(days: 30)), // Far in the future
      );
      expect(TripStateManager.getPriority(normalTrip), equals(TripPriority.low));
    });

    test('should return correct action labels', () {
      expect(TripStateManager.getActionLabel(TripAction.publish), equals('Publier'));
      expect(TripStateManager.getActionLabel(TripAction.pause), equals('Mettre en pause'));
      expect(TripStateManager.getActionLabel(TripAction.cancel), equals('Annuler'));
    });

    test('should return correct status colors', () {
      expect(TripStateManager.getStatusColor(TripStatus.draft), equals('#6B7280'));
      expect(TripStateManager.getStatusColor(TripStatus.active), equals('#10B981'));
      expect(TripStateManager.getStatusColor(TripStatus.rejected), equals('#EF4444'));
    });

    test('should return next possible statuses', () {
      final nextStatuses = TripStateManager.getNextPossibleStatuses(TripStatus.draft);
      expect(nextStatuses, contains(TripStatus.pendingReview));
      expect(nextStatuses, contains(TripStatus.active));
      expect(nextStatuses, hasLength(2));
    });
  });

  group('Trip Model', () {
    test('should create trip with all new fields', () {
      final trip = Trip(
        id: '1',
        uuid: 'test-uuid',
        userId: 'user-1',
        transportType: 'flight',
        departureCity: 'Montreal',
        departureCountry: 'Canada',
        departureDate: DateTime.now().add(const Duration(days: 7)),
        arrivalCity: 'Paris',
        arrivalCountry: 'France',
        arrivalDate: DateTime.now().add(const Duration(days: 8)),
        availableWeightKg: 20.0,
        pricePerKg: 15.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: TripStatus.active,
        
        // New fields
        publishedAt: DateTime.now(),
        isUrgent: true,
        isFeatured: false,
        isVerified: true,
        autoApproved: true,
        shareCount: 10,
        favoriteCount: 5,
        viewCount: 100,
        visibility: 'public',
        minUserRating: 4.5,
        version: 2,
      );

      expect(trip.isUrgent, isTrue);
      expect(trip.isFeatured, isFalse);
      expect(trip.isVerified, isTrue);
      expect(trip.autoApproved, isTrue);
      expect(trip.shareCount, equals(10));
      expect(trip.favoriteCount, equals(5));
      expect(trip.viewCount, equals(100));
      expect(trip.visibility, equals('public'));
      expect(trip.minUserRating, equals(4.5));
      expect(trip.version, equals(2));
      expect(trip.publishedAt, isNotNull);
    });

    test('should serialize and deserialize correctly', () {
      final originalTrip = Trip(
        id: '1',
        uuid: 'test-uuid',
        userId: 'user-1',
        transportType: 'flight',
        departureCity: 'Montreal',
        departureCountry: 'Canada',
        departureDate: DateTime.now().add(const Duration(days: 7)),
        arrivalCity: 'Paris',
        arrivalCountry: 'France',
        arrivalDate: DateTime.now().add(const Duration(days: 8)),
        availableWeightKg: 20.0,
        pricePerKg: 15.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: TripStatus.active,
        shareCount: 10,
        favoriteCount: 5,
      );

      final json = originalTrip.toJson();
      final deserializedTrip = Trip.fromJson(json);

      expect(deserializedTrip.id, equals(originalTrip.id));
      expect(deserializedTrip.shareCount, equals(originalTrip.shareCount));
      expect(deserializedTrip.favoriteCount, equals(originalTrip.favoriteCount));
      expect(deserializedTrip.status, equals(originalTrip.status));
    });

    test('should handle copyWith with new fields', () {
      final originalTrip = Trip(
        id: '1',
        uuid: 'test-uuid',
        userId: 'user-1',
        transportType: 'flight',
        departureCity: 'Montreal',
        departureCountry: 'Canada',
        departureDate: DateTime.now().add(const Duration(days: 7)),
        arrivalCity: 'Paris',
        arrivalCountry: 'France',
        arrivalDate: DateTime.now().add(const Duration(days: 8)),
        availableWeightKg: 20.0,
        pricePerKg: 15.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: TripStatus.draft,
        shareCount: 0,
      );

      final updatedTrip = originalTrip.copyWith(
        status: TripStatus.active,
        shareCount: 15,
        publishedAt: DateTime.now(),
      );

      expect(updatedTrip.status, equals(TripStatus.active));
      expect(updatedTrip.shareCount, equals(15));
      expect(updatedTrip.publishedAt, isNotNull);
      expect(updatedTrip.id, equals(originalTrip.id)); // Unchanged fields preserved
    });
  });
}