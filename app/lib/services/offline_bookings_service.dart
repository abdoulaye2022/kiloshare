import '../modules/booking/models/booking_model.dart';
import '../modules/booking/services/booking_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class OfflineBookingsService {
  static final OfflineBookingsService _instance = OfflineBookingsService._internal();
  factory OfflineBookingsService() => _instance;
  OfflineBookingsService._internal();

  final BookingService _bookingService = BookingService.instance;
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<BookingModel>> getMyBookings() async {
    if (_connectivity.isOnline) {
      try {
        final result = await _bookingService.getUserBookings();
        if (!result['success']) {
          throw Exception(result['error'] ?? 'Failed to get bookings');
        }
        final bookings = (result['bookings'] as List<dynamic>?)
          ?.map((json) => BookingModel.fromJson(json))
          .toList() ?? [];
        await _cache.cacheMyBookings(bookings);
        _connectivity.markSyncSuccessful();
        return bookings;
      } catch (e) {
        // Si l'API échoue, utiliser le cache
        final cached = await _cache.getCachedMyBookings();
        if (cached != null) {
          return cached;
        }
        rethrow;
      }
    } else {
      // Mode offline, utiliser uniquement le cache
      final cached = await _cache.getCachedMyBookings();
      return cached ?? [];
    }
  }

  Future<List<BookingModel>?> getCachedBookings() async {
    return await _cache.getCachedMyBookings();
  }

  /// Récupérer les réservations envoyées par l'utilisateur
  Future<List<BookingModel>> getSentBookings() async {
    if (_connectivity.isOnline) {
      try {
        final bookings = await _bookingService.getSentBookings();
        await _cache.cacheSentBookings(bookings);
        _connectivity.markSyncSuccessful();
        return bookings;
      } catch (e) {
        // Si l'API échoue, utiliser le cache
        final cached = await _cache.getCachedSentBookings();
        if (cached != null) {
          return cached;
        }
        rethrow;
      }
    } else {
      // Mode offline, utiliser uniquement le cache
      final cached = await _cache.getCachedSentBookings();
      return cached ?? [];
    }
  }

  /// Récupérer les réservations reçues par l'utilisateur
  Future<List<BookingModel>> getReceivedBookings() async {
    if (_connectivity.isOnline) {
      try {
        final bookings = await _bookingService.getReceivedBookings();
        await _cache.cacheReceivedBookings(bookings);
        _connectivity.markSyncSuccessful();
        return bookings;
      } catch (e) {
        // Si l'API échoue, utiliser le cache
        final cached = await _cache.getCachedReceivedBookings();
        if (cached != null) {
          return cached;
        }
        rethrow;
      }
    } else {
      // Mode offline, utiliser uniquement le cache
      final cached = await _cache.getCachedReceivedBookings();
      return cached ?? [];
    }
  }

  /// Cache des réservations envoyées
  Future<List<BookingModel>?> getCachedSentBookings() async {
    return await _cache.getCachedSentBookings();
  }

  /// Cache des réservations reçues
  Future<List<BookingModel>?> getCachedReceivedBookings() async {
    return await _cache.getCachedReceivedBookings();
  }

  Future<void> refreshBookings() async {
    if (_connectivity.isOnline) {
      final result = await _bookingService.getUserBookings();
      if (!result['success']) {
        throw Exception(result['error'] ?? 'Failed to get bookings');
      }
      final bookings = (result['bookings'] as List<dynamic>?)
        ?.map((json) => BookingModel.fromJson(json))
        .toList() ?? [];
      await _cache.cacheMyBookings(bookings);
      _connectivity.markSyncSuccessful();
    }
  }

  bool get isOffline => _connectivity.isOffline;
  bool get isOnline => _connectivity.isOnline;
}