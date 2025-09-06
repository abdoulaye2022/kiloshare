import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modules/trips/models/trip_model.dart' show Trip;
import '../modules/booking/models/booking_model.dart';
import 'connectivity_service.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _myTripsKey = 'cached_my_trips';
  static const String _myBookingsKey = 'cached_my_bookings';
  static const String _lastSearchKey = 'cached_last_search';
  static const String _cacheTimestampKey = 'cache_timestamp_';
  
  static const int maxTrips = 50;
  static const int maxBookings = 20;
  static const int cacheDurationDays = 7;

  final ConnectivityService _connectivity = ConnectivityService();

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // CACHE MES ANNONCES
  Future<void> cacheMyTrips(List<Trip> trips) async {
    if (_connectivity.isOffline) return;
    
    try {
      final prefs = await _prefs;
      final limitedTrips = trips.take(maxTrips).toList();
      final tripsJson = limitedTrips.map((trip) => trip.toJson()).toList();
      
      await prefs.setString(_myTripsKey, json.encode(tripsJson));
      await _setCacheTimestamp(_myTripsKey);
      
      debugPrint('✅ ${limitedTrips.length} trips cached');
    } catch (e) {
      debugPrint('❌ Error caching trips: $e');
    }
  }

  Future<List<Trip>?> getCachedMyTrips() async {
    try {
      final prefs = await _prefs;
      
      if (!_isCacheValid(_myTripsKey, prefs)) {
        await _clearCache(_myTripsKey, prefs);
        return null;
      }

      final tripsJson = prefs.getString(_myTripsKey);
      if (tripsJson == null) return null;

      final List<dynamic> tripsList = json.decode(tripsJson);
      return tripsList.map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error loading cached trips: $e');
      return null;
    }
  }

  // CACHE MES RÉSERVATIONS
  Future<void> cacheMyBookings(List<BookingModel> bookings) async {
    if (_connectivity.isOffline) return;
    
    try {
      final prefs = await _prefs;
      final limitedBookings = bookings.take(maxBookings).toList();
      final bookingsJson = limitedBookings.map((booking) => booking.toJson()).toList();
      
      await prefs.setString(_myBookingsKey, json.encode(bookingsJson));
      await _setCacheTimestamp(_myBookingsKey);
      
      debugPrint('✅ ${limitedBookings.length} bookings cached');
    } catch (e) {
      debugPrint('❌ Error caching bookings: $e');
    }
  }

  Future<List<BookingModel>?> getCachedMyBookings() async {
    try {
      final prefs = await _prefs;
      
      if (!_isCacheValid(_myBookingsKey, prefs)) {
        await _clearCache(_myBookingsKey, prefs);
        return null;
      }

      final bookingsJson = prefs.getString(_myBookingsKey);
      if (bookingsJson == null) return null;

      final List<dynamic> bookingsList = json.decode(bookingsJson);
      return bookingsList.map((json) => BookingModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error loading cached bookings: $e');
      return null;
    }
  }

  // CACHE DERNIÈRE RECHERCHE
  Future<void> cacheLastSearch(Map<String, dynamic> searchData) async {
    if (_connectivity.isOffline) return;
    
    try {
      final prefs = await _prefs;
      await prefs.setString(_lastSearchKey, json.encode(searchData));
      await _setCacheTimestamp(_lastSearchKey);
      
      debugPrint('✅ Last search cached');
    } catch (e) {
      debugPrint('❌ Error caching search: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedLastSearch() async {
    try {
      final prefs = await _prefs;
      
      if (!_isCacheValid(_lastSearchKey, prefs)) {
        await _clearCache(_lastSearchKey, prefs);
        return null;
      }

      final searchJson = prefs.getString(_lastSearchKey);
      if (searchJson == null) return null;

      return json.decode(searchJson);
    } catch (e) {
      debugPrint('❌ Error loading cached search: $e');
      return null;
    }
  }

  // UTILITAIRES
  Future<void> _setCacheTimestamp(String key) async {
    final prefs = await _prefs;
    await prefs.setInt('$_cacheTimestampKey$key', DateTime.now().millisecondsSinceEpoch);
  }

  bool _isCacheValid(String key, SharedPreferences prefs) {
    final timestamp = prefs.getInt('$_cacheTimestampKey$key');
    if (timestamp == null) return false;

    final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cacheDate);

    return difference.inDays < cacheDurationDays;
  }

  Future<void> _clearCache(String key, SharedPreferences prefs) async {
    await prefs.remove(key);
    await prefs.remove('$_cacheTimestampKey$key');
  }

  // NETTOYAGE COMPLET
  Future<void> clearAllCache() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_myTripsKey);
      await prefs.remove(_myBookingsKey);
      await prefs.remove(_lastSearchKey);
      await prefs.remove('$_cacheTimestampKey$_myTripsKey');
      await prefs.remove('$_cacheTimestampKey$_myBookingsKey');
      await prefs.remove('$_cacheTimestampKey$_lastSearchKey');
      
      debugPrint('✅ All cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  // STATISTIQUES CACHE
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await _prefs;
      
      return {
        'myTrips': {
          'count': (await getCachedMyTrips())?.length ?? 0,
          'valid': _isCacheValid(_myTripsKey, prefs),
        },
        'myBookings': {
          'count': (await getCachedMyBookings())?.length ?? 0,
          'valid': _isCacheValid(_myBookingsKey, prefs),
        },
        'lastSearch': {
          'exists': (await getCachedLastSearch()) != null,
          'valid': _isCacheValid(_lastSearchKey, prefs),
        },
      };
    } catch (e) {
      return {};
    }
  }
}