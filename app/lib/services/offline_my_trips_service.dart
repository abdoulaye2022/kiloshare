import '../modules/trips/models/trip_model.dart';
import '../modules/trips/services/trip_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class OfflineMyTripsService {
  static final OfflineMyTripsService _instance = OfflineMyTripsService._internal();
  factory OfflineMyTripsService() => _instance;
  OfflineMyTripsService._internal();

  final TripService _tripService = TripService();
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<Trip>> getMyTrips() async {
    if (_connectivity.isOnline) {
      try {
        final trips = await _tripService.getUserTrips();
        await _cache.cacheMyTrips(trips);
        _connectivity.markSyncSuccessful();
        return trips;
      } catch (e) {
        // Si l'API échoue, utiliser le cache
        final cached = await _cache.getCachedMyTrips();
        if (cached != null) {
          return cached;
        }
        rethrow;
      }
    } else {
      // Mode offline, utiliser uniquement le cache
      final cached = await _cache.getCachedMyTrips();
      return cached ?? [];
    }
  }

  Future<List<Trip>?> getCachedTrips() async {
    return await _cache.getCachedMyTrips();
  }

  Future<void> refreshTrips() async {
    if (_connectivity.isOnline) {
      final trips = await _tripService.getUserTrips();
      await _cache.cacheMyTrips(trips);
      _connectivity.markSyncSuccessful();
    }
  }

  bool get isOffline => _connectivity.isOffline;
  bool get isOnline => _connectivity.isOnline;
}