import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../services/favorites_service.dart';

/// Gestionnaire d'état centralisé pour la page "Mes voyages"
/// Optimise la gestion des données entre les onglets Voyages, Brouillons et Favoris
class MyTripsStateManager extends ChangeNotifier {
  static MyTripsStateManager? _instance;
  static MyTripsStateManager get instance => _instance ??= MyTripsStateManager._();
  
  MyTripsStateManager._();

  final TripService _tripService = TripService();
  
  // États des données
  List<Trip> _allTrips = [];
  List<Trip> _myTrips = [];
  List<Trip> _drafts = [];
  List<Trip> _favorites = [];
  
  // États filtrés (après application des filtres)
  List<Trip> _filteredTrips = [];
  List<Trip> _filteredDrafts = [];
  List<Trip> _filteredFavorites = [];
  
  // États de loading par onglet
  bool _isLoadingTrips = false;
  bool _isLoadingDrafts = false;
  bool _isLoadingFavorites = false;
  
  // États d'erreur par onglet
  String? _errorTrips;
  String? _errorDrafts;
  String? _errorFavorites;
  
  // Filtres actuels
  String _statusFilter = 'all';
  String _sortBy = 'date';
  bool _sortAscending = false;
  String _searchQuery = '';
  
  // Filtres avancés
  String _transportFilter = 'all';
  DateTimeRange? _dateRange;
  double _minPrice = 0;
  double _maxPrice = 1000;
  double _minWeight = 0;
  double _maxWeight = 1000;
  String _currencyFilter = 'all';
  bool _showExpiredTrips = true;
  
  // Timestamp de dernière synchronisation par onglet
  DateTime? _lastSyncTrips;
  DateTime? _lastSyncDrafts;
  DateTime? _lastSyncFavorites;
  
  // Durée de cache (évite les appels API trop fréquents)
  static const Duration _cacheDuration = Duration(minutes: 2);

  // Getters pour les données
  List<Trip> get allTrips => _allTrips;
  List<Trip> get myTrips => _myTrips;
  List<Trip> get drafts => _drafts;
  List<Trip> get favorites => _favorites;
  
  List<Trip> get filteredTrips => _filteredTrips;
  List<Trip> get filteredDrafts => _filteredDrafts;
  List<Trip> get filteredFavorites => _filteredFavorites;
  
  // Getters pour les états de loading
  bool get isLoadingTrips => _isLoadingTrips;
  bool get isLoadingDrafts => _isLoadingDrafts;
  bool get isLoadingFavorites => _isLoadingFavorites;
  bool get isLoadingAny => _isLoadingTrips || _isLoadingDrafts || _isLoadingFavorites;
  
  // Getters pour les erreurs
  String? get errorTrips => _errorTrips;
  String? get errorDrafts => _errorDrafts;
  String? get errorFavorites => _errorFavorites;
  
  // Getters pour les filtres
  String get statusFilter => _statusFilter;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get searchQuery => _searchQuery;
  String get transportFilter => _transportFilter;
  DateTimeRange? get dateRange => _dateRange;
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  double get minWeight => _minWeight;
  double get maxWeight => _maxWeight;
  String get currencyFilter => _currencyFilter;
  bool get showExpiredTrips => _showExpiredTrips;

  /// Charge tous les onglets en parallèle lors de l'initialisation
  Future<void> loadAllData({bool force = false}) async {
    debugPrint('MyTripsStateManager: Loading all data (force: $force)...');
    
    await Future.wait([
      loadTripsData(force: force),
      loadDraftsData(force: force),
      loadFavoritesData(force: force),
    ]);
  }

  /// Charge les données de l'onglet Voyages
  Future<void> loadTripsData({bool force = false}) async {
    // Vérifier le cache si pas forcé
    if (!force && _shouldUseCache(_lastSyncTrips)) {
      debugPrint('MyTripsStateManager: Using cached trips data');
      return;
    }
    
    _setLoadingTrips(true);
    _errorTrips = null;
    
    try {
      debugPrint('MyTripsStateManager: Fetching trips from API...');
      final trips = await _tripService.getUserTrips();
      
      _allTrips = trips;
      _myTrips = trips.where((trip) => trip.status != TripStatus.draft).toList();
      _lastSyncTrips = DateTime.now();
      
      debugPrint('MyTripsStateManager: Loaded ${_myTrips.length} published trips');
      _applyFilters();
    } catch (e) {
      debugPrint('MyTripsStateManager: Error loading trips: $e');
      _errorTrips = e.toString();
    } finally {
      _setLoadingTrips(false);
    }
  }

  /// Charge les données de l'onglet Brouillons
  Future<void> loadDraftsData({bool force = false}) async {
    // Vérifier le cache si pas forcé
    if (!force && _shouldUseCache(_lastSyncDrafts)) {
      debugPrint('MyTripsStateManager: Using cached drafts data');
      return;
    }
    
    _setLoadingDrafts(true);
    _errorDrafts = null;
    
    try {
      debugPrint('MyTripsStateManager: Fetching drafts from API...');
      List<Trip> drafts;
      
      try {
        // Essayer l'endpoint dédié aux brouillons
        drafts = await _tripService.getDrafts();
      } catch (e) {
        debugPrint('MyTripsStateManager: Drafts endpoint failed, falling back to filtering: $e');
        // Fallback : filtrer depuis les trips existants
        if (_allTrips.isEmpty) {
          final trips = await _tripService.getUserTrips();
          _allTrips = trips;
        }
        drafts = _allTrips.where((trip) => trip.status == TripStatus.draft).toList();
      }
      
      _drafts = drafts;
      _lastSyncDrafts = DateTime.now();
      
      debugPrint('MyTripsStateManager: Loaded ${_drafts.length} drafts');
      _applyFilters();
    } catch (e) {
      debugPrint('MyTripsStateManager: Error loading drafts: $e');
      _errorDrafts = e.toString();
    } finally {
      _setLoadingDrafts(false);
    }
  }

  /// Charge les données de l'onglet Favoris
  Future<void> loadFavoritesData({bool force = false}) async {
    // Vérifier le cache si pas forcé
    if (!force && _shouldUseCache(_lastSyncFavorites)) {
      debugPrint('MyTripsStateManager: Using cached favorites data');
      return;
    }
    
    _setLoadingFavorites(true);
    _errorFavorites = null;
    
    try {
      debugPrint('MyTripsStateManager: Fetching favorites from API...');
      final favorites = await FavoritesService.instance.getFavoriteTrips();
      
      _favorites = favorites;
      _lastSyncFavorites = DateTime.now();
      
      debugPrint('MyTripsStateManager: Loaded ${_favorites.length} favorites');
      _applyFilters();
    } catch (e) {
      debugPrint('MyTripsStateManager: Error loading favorites: $e');
      _errorFavorites = e.toString();
    } finally {
      _setLoadingFavorites(false);
    }
  }

  /// Actualise les données d'un onglet spécifique
  Future<void> refreshTab(int tabIndex) async {
    switch (tabIndex) {
      case 0:
        await loadTripsData(force: true);
        break;
      case 1:
        await loadDraftsData(force: true);
        break;
      case 2:
        await loadFavoritesData(force: true);
        break;
    }
  }

  /// Met à jour les filtres et applique immédiatement
  void updateFilters({
    String? statusFilter,
    String? sortBy,
    bool? sortAscending,
    String? searchQuery,
    String? transportFilter,
    DateTimeRange? dateRange,
    double? minPrice,
    double? maxPrice,
    double? minWeight,
    double? maxWeight,
    String? currencyFilter,
    bool? showExpiredTrips,
  }) {
    bool hasChanged = false;
    
    if (statusFilter != null && _statusFilter != statusFilter) {
      _statusFilter = statusFilter;
      hasChanged = true;
    }
    if (sortBy != null && _sortBy != sortBy) {
      _sortBy = sortBy;
      hasChanged = true;
    }
    if (sortAscending != null && _sortAscending != sortAscending) {
      _sortAscending = sortAscending;
      hasChanged = true;
    }
    if (searchQuery != null && _searchQuery != searchQuery) {
      _searchQuery = searchQuery;
      hasChanged = true;
    }
    if (transportFilter != null && _transportFilter != transportFilter) {
      _transportFilter = transportFilter;
      hasChanged = true;
    }
    if (dateRange != _dateRange) {
      _dateRange = dateRange;
      hasChanged = true;
    }
    if (minPrice != null && _minPrice != minPrice) {
      _minPrice = minPrice;
      hasChanged = true;
    }
    if (maxPrice != null && _maxPrice != maxPrice) {
      _maxPrice = maxPrice;
      hasChanged = true;
    }
    if (minWeight != null && _minWeight != minWeight) {
      _minWeight = minWeight;
      hasChanged = true;
    }
    if (maxWeight != null && _maxWeight != maxWeight) {
      _maxWeight = maxWeight;
      hasChanged = true;
    }
    if (currencyFilter != null && _currencyFilter != currencyFilter) {
      _currencyFilter = currencyFilter;
      hasChanged = true;
    }
    if (showExpiredTrips != null && _showExpiredTrips != showExpiredTrips) {
      _showExpiredTrips = showExpiredTrips;
      hasChanged = true;
    }
    
    if (hasChanged) {
      _applyFilters();
    }
  }

  /// Réinitialise tous les filtres avancés
  void resetAdvancedFilters() {
    updateFilters(
      transportFilter: 'all',
      dateRange: null,
      minPrice: 0,
      maxPrice: 1000,
      minWeight: 0,
      maxWeight: 1000,
      currencyFilter: 'all',
      showExpiredTrips: true,
    );
  }

  /// Vérifie si des filtres avancés sont appliqués
  bool hasAdvancedFilters() {
    return _transportFilter != 'all' ||
           _dateRange != null ||
           _minPrice > 0 ||
           _maxPrice < 1000 ||
           _minWeight > 0 ||
           _maxWeight < 1000 ||
           _currencyFilter != 'all' ||
           !_showExpiredTrips;
  }

  /// Applique tous les filtres aux trois listes
  void _applyFilters() {
    debugPrint('MyTripsStateManager: Applying filters...');
    
    // Appliquer aux voyages publiés
    _filteredTrips = _applyFiltersToList(_myTrips);
    
    // Appliquer aux brouillons
    _filteredDrafts = _applyFiltersToList(_drafts);
    
    // Appliquer aux favoris
    _filteredFavorites = _applyFiltersToList(_favorites);
    
    debugPrint('MyTripsStateManager: Filters applied - Trips: ${_filteredTrips.length}, Drafts: ${_filteredDrafts.length}, Favorites: ${_filteredFavorites.length}');
    notifyListeners();
  }

  /// Applique les filtres à une liste donnée
  List<Trip> _applyFiltersToList(List<Trip> trips) {
    List<Trip> filtered = List.from(trips);
    
    // Filtre par statut
    if (_statusFilter != 'all') {
      filtered = filtered.where((trip) {
        switch (_statusFilter) {
          case 'active':
            return trip.status == TripStatus.active;
          case 'paused':
            return trip.status == TripStatus.paused;
          case 'pending':
            return trip.status == TripStatus.pendingApproval || 
                   trip.status == TripStatus.pendingReview;
          case 'completed':
            return trip.status == TripStatus.completed;
          case 'cancelled':
            return trip.status == TripStatus.cancelled;
          default:
            return true;
        }
      }).toList();
    }
    
    // Filtres avancés
    filtered.removeWhere((trip) {
      // Type de transport
      if (_transportFilter != 'all' && trip.transportType != _transportFilter) {
        return true;
      }
      
      // Plage de dates
      if (_dateRange != null) {
        final departureDate = DateTime(trip.departureDate.year, trip.departureDate.month, trip.departureDate.day);
        final rangeStart = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final rangeEnd = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        
        if (departureDate.isBefore(rangeStart) || departureDate.isAfter(rangeEnd)) {
          return true;
        }
      }
      
      // Plage de prix
      if (trip.pricePerKg < _minPrice || trip.pricePerKg > _maxPrice) {
        return true;
      }
      
      // Plage de poids
      if (trip.availableWeightKg < _minWeight || trip.availableWeightKg > _maxWeight) {
        return true;
      }
      
      // Devise
      if (_currencyFilter != 'all' && trip.currency != _currencyFilter) {
        return true;
      }
      
      // Voyages expirés
      if (!_showExpiredTrips && trip.departureDate.isBefore(DateTime.now())) {
        return true;
      }
      
      return false;
    });
    
    // Filtre par recherche textuelle
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((trip) => 
        trip.departureCity.toLowerCase().contains(query) ||
        trip.arrivalCity.toLowerCase().contains(query) ||
        (trip.flightNumber?.toLowerCase().contains(query) ?? false) ||
        (trip.airline?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    // Tri
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'date':
          comparison = a.departureDate.compareTo(b.departureDate);
          break;
        case 'destination':
          comparison = a.arrivalCity.compareTo(b.arrivalCity);
          break;
        case 'price':
          comparison = a.pricePerKg.compareTo(b.pricePerKg);
          break;
        case 'capacity':
          comparison = a.availableWeightKg.compareTo(b.availableWeightKg);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }

  /// Méthodes pour mettre à jour les états de loading
  void _setLoadingTrips(bool loading) {
    if (_isLoadingTrips != loading) {
      _isLoadingTrips = loading;
      notifyListeners();
    }
  }

  void _setLoadingDrafts(bool loading) {
    if (_isLoadingDrafts != loading) {
      _isLoadingDrafts = loading;
      notifyListeners();
    }
  }

  void _setLoadingFavorites(bool loading) {
    if (_isLoadingFavorites != loading) {
      _isLoadingFavorites = loading;
      notifyListeners();
    }
  }

  /// Vérifie si on peut utiliser le cache
  bool _shouldUseCache(DateTime? lastSync) {
    if (lastSync == null) return false;
    return DateTime.now().difference(lastSync) < _cacheDuration;
  }

  /// Invalide le cache (force le rechargement des données)
  void invalidateCache() {
    _lastSyncTrips = null;
    _lastSyncDrafts = null;
    _lastSyncFavorites = null;
    debugPrint('MyTripsStateManager: Cache invalidated');
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    _instance = null;
    super.dispose();
  }

  /// Statistiques pour l'interface
  Map<String, dynamic> getStatistics() {
    return {
      'totalTrips': _allTrips.length,
      'publishedTrips': _myTrips.length,
      'drafts': _drafts.length,
      'favorites': _favorites.length,
      'totalEarnings': _allTrips.fold(0.0, (sum, trip) => sum + trip.totalEarningsPotential),
      'totalCapacity': _allTrips.fold(0.0, (sum, trip) => sum + trip.availableWeightKg),
      'mostPopularTrip': _getMostPopularTrip(),
    };
  }

  String _getMostPopularTrip() {
    if (_allTrips.isEmpty) return 'Aucun voyage';
    
    final mostPopular = _allTrips.reduce((a, b) => 
      a.viewCount > b.viewCount ? a : b
    );
    
    return '${mostPopular.routeDisplay} (${mostPopular.viewCount} vues)';
  }
}