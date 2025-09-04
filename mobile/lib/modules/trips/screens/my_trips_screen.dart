import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trip_model.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/trip_status_widget.dart';
import '../services/trip_state_manager.dart';
import '../services/trip_service.dart';
import '../services/favorites_service.dart';
import '../../../widgets/ellipsis_button.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TripService _tripService = TripService();
  
  List<Trip> _allTrips = [];
  List<Trip> _myTrips = [];
  List<Trip> _drafts = [];
  List<Trip> _favorites = [];
  List<Trip> _filteredTrips = [];
  List<Trip> _filteredDrafts = [];
  List<Trip> _filteredFavorites = [];
  bool _isLoading = false;
  String? _error;
  
  // Filtering and sorting
  String _statusFilter = 'all';
  String _sortBy = 'date';
  bool _sortAscending = false;
  String _searchQuery = '';
  
  // Advanced filters
  String _transportFilter = 'all';
  DateTimeRange? _dateRange;
  double _minPrice = 0;
  double _maxPrice = 1000;
  double _minWeight = 0;
  double _maxWeight = 1000;
  String _currencyFilter = 'all';
  bool _showExpiredTrips = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Ajouter un listener pour synchroniser les données quand on change d'onglet
    _tabController.addListener(_onTabChanged);
    
    // Initialize filtered lists
    _filteredTrips = [];
    _filteredDrafts = [];
    _filteredFavorites = [];
    _loadTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    print('MyTripsScreen: Starting to load trips...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('MyTripsScreen: Calling getUserTrips...');
      final trips = await _tripService.getUserTrips();
      print('MyTripsScreen: Received ${trips.length} trips');
      
      List<Trip> drafts = [];
      List<Trip> favorites = [];
      
      try {
        drafts = await _tripService.getDrafts();
        print('MyTripsScreen: Received ${drafts.length} drafts');
      } catch (e) {
        print('MyTripsScreen: Failed to load drafts: $e');
        // Fallback: filter drafts from main trips list
        drafts = trips.where((trip) => trip.status == TripStatus.draft).toList();
      }
      
      try {
        favorites = await FavoritesService.instance.getFavoriteTrips();
        print('MyTripsScreen: Received ${favorites.length} favorites');
      } catch (e) {
        print('MyTripsScreen: Failed to load favorites: $e');
        // Fallback: empty list for now
        favorites = [];
      }
      
      setState(() {
        // All trips from getUserTrips (should only be user's own trips, excluding favorites)
        _allTrips = trips;
        
        // Published trips: user's own published trips (drafts are excluded by API)
        _myTrips = trips;
        
        // Drafts: from dedicated endpoint (user's own draft trips)
        _drafts = drafts;
        
        // Favorites: from dedicated endpoint (other users' trips that this user favorited)  
        _favorites = favorites;
        
        print('MyTripsScreen: All user trips: ${trips.length}');
        print('MyTripsScreen: Published trips: ${_myTrips.length}');
        print('MyTripsScreen: Drafts: ${_drafts.length}');
        print('MyTripsScreen: Favorites: ${_favorites.length}');
        print('MyTripsScreen: All trips statuses: ${trips.map((t) => '${t.id}:${t.status.value}').join(', ')}');
        print('MyTripsScreen: Draft IDs: ${_drafts.map((t) => t.id).join(', ')}');
        print('MyTripsScreen: Favorite IDs: ${_favorites.map((t) => t.id).join(', ')}');
        
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('MyTripsScreen: Error loading trips: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Listener pour les changements d'onglet
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return; // Éviter les appels multiples
    
    print('MyTripsScreen: Tab changed to index ${_tabController.index}');
    
    switch (_tabController.index) {
      case 0: // Onglet Voyages
        _syncTripsData();
        break;
      case 1: // Onglet Brouillons
        _syncDraftsData();
        break;
      case 2: // Onglet Favoris
        _syncFavoritesData();
        break;
    }
  }

  // Synchroniser les données de l'onglet Voyages
  Future<void> _syncTripsData() async {
    print('MyTripsScreen: Synchronizing trips data...');
    try {
      final trips = await _tripService.getUserTrips();
      setState(() {
        _allTrips = trips;
        _myTrips = trips.where((trip) => trip.status != TripStatus.draft).toList();
        _applyFilters();
      });
      print('MyTripsScreen: Trips data synchronized - ${_myTrips.length} trips');
    } catch (e) {
      print('MyTripsScreen: Error synchronizing trips data: $e');
    }
  }

  // Synchroniser les données de l'onglet Brouillons
  Future<void> _syncDraftsData() async {
    print('MyTripsScreen: Synchronizing drafts data...');
    try {
      final trips = await _tripService.getUserTrips();
      setState(() {
        _allTrips = trips;
        _drafts = trips.where((trip) => trip.status == TripStatus.draft).toList();
        _applyFilters();
      });
      print('MyTripsScreen: Drafts data synchronized - ${_drafts.length} drafts');
    } catch (e) {
      print('MyTripsScreen: Error synchronizing drafts data: $e');
    }
  }

  // Synchroniser les données de l'onglet Favoris
  Future<void> _syncFavoritesData() async {
    print('MyTripsScreen: Synchronizing favorites data...');
    try {
      final favoriteTrips = await FavoritesService.instance.getFavoriteTrips();
      setState(() {
        _favorites = favoriteTrips;
        _applyFilters();
      });
      print('MyTripsScreen: Favorites data synchronized - ${_favorites.length} favorites');
    } catch (e) {
      print('MyTripsScreen: Error synchronizing favorites data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes voyages'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher dans mes voyages...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
              
              // Filter chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('Tous', 'all'),
                    _buildFilterChip('Actifs', 'active'),
                    _buildFilterChip('En pause', 'paused'),
                    _buildFilterChip('En attente', 'pending'),
                    _buildFilterChip('Terminés', 'completed'),
                    _buildFilterChip('Annulés', 'cancelled'),
                    const SizedBox(width: 8),
                    _buildSortButton(),
                    const SizedBox(width: 8),
                    _buildAdvancedFilterButton(),
                  ],
                ),
              ),
              
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: false,
                tabs: [
                  Tab(
                    text: 'Voyages (${_filteredTrips.length})',
                    icon: const Icon(Icons.flight_takeoff),
                  ),
                  Tab(
                    text: 'Brouillons (${_filteredDrafts.length})',
                    icon: const Icon(Icons.drafts),
                  ),
                  Tab(
                    text: 'Favoris (${_filteredFavorites.length})',
                    icon: const Icon(Icons.favorite),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/trips/create'),
            tooltip: 'Nouveau voyage',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'statistics',
                child: ListTile(
                  leading: Icon(Icons.analytics),
                  title: Text('Statistiques'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Exporter'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTripsTab(_filteredTrips, 'Aucun voyage publié', showActions: true),
          _buildTripsTab(_filteredDrafts, 'Aucun brouillon', showActions: true),
          _buildTripsTab(_filteredFavorites, 'Aucun voyage favori', showActions: false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/create'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau voyage'),
      ),
    );
  }

  Widget _buildTripsTab(List<Trip> trips, String emptyMessage, {bool showActions = true}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (trips.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          return Column(
            children: [
              TripCardWidget(
                trip: trip,
                showUserInfo: false,
                onTap: () => context.push('/trips/${trip.id}'),
              ),
              const SizedBox(height: 8),
              TripStatusWidget(
                trip: trip,
                showDetails: false, // Less details in list view
                showMetrics: true,
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier voyage et commencez à partager !',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/trips/create'),
              icon: const Icon(Icons.add),
              label: const Text('Créer un voyage'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 150,
            child: ElevatedButton.icon(
              onPressed: _loadTrips,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    List<Trip> filteredPublished = List.from(_myTrips);
    List<Trip> filteredDrafts = List.from(_drafts);
    List<Trip> filteredFavorites = List.from(_favorites);

    // Apply status filter
    if (_statusFilter != 'all') {
      switch (_statusFilter) {
        case 'active':
          filteredPublished = filteredPublished.where((trip) => trip.status == TripStatus.active).toList();
          break;
        case 'paused':
          filteredPublished = filteredPublished.where((trip) => trip.status == TripStatus.paused).toList();
          break;
        case 'pending':
          filteredPublished = filteredPublished.where((trip) => 
            trip.status == TripStatus.pendingApproval || trip.status == TripStatus.pendingReview).toList();
          break;
        case 'completed':
          filteredPublished = filteredPublished.where((trip) => trip.status == TripStatus.completed).toList();
          break;
        case 'cancelled':
          filteredPublished = filteredPublished.where((trip) => trip.status == TripStatus.cancelled).toList();
          break;
      }
    }

    // Apply advanced filters
    _applyAdvancedFilters(filteredPublished);
    _applyAdvancedFilters(filteredDrafts);
    _applyAdvancedFilters(filteredFavorites);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredPublished = filteredPublished.where((trip) => 
        trip.departureCity.toLowerCase().contains(query) ||
        trip.arrivalCity.toLowerCase().contains(query) ||
        (trip.flightNumber?.toLowerCase().contains(query) ?? false) ||
        (trip.airline?.toLowerCase().contains(query) ?? false)
      ).toList();
      
      filteredDrafts = filteredDrafts.where((trip) => 
        trip.departureCity.toLowerCase().contains(query) ||
        trip.arrivalCity.toLowerCase().contains(query) ||
        (trip.flightNumber?.toLowerCase().contains(query) ?? false) ||
        (trip.airline?.toLowerCase().contains(query) ?? false)
      ).toList();
      
      filteredFavorites = filteredFavorites.where((trip) => 
        trip.departureCity.toLowerCase().contains(query) ||
        trip.arrivalCity.toLowerCase().contains(query) ||
        (trip.flightNumber?.toLowerCase().contains(query) ?? false) ||
        (trip.airline?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    // Apply sorting
    _applySorting(filteredPublished);
    _applySorting(filteredDrafts);
    _applySorting(filteredFavorites);

    setState(() {
      _filteredTrips = filteredPublished;
      _filteredDrafts = filteredDrafts;
      _filteredFavorites = filteredFavorites;
    });
  }

  void _applyAdvancedFilters(List<Trip> trips) {
    trips.removeWhere((trip) {
      // Transport type filter
      if (_transportFilter != 'all' && trip.transportType != _transportFilter) {
        return true;
      }
      
      // Date range filter
      if (_dateRange != null) {
        final departureDate = DateTime(trip.departureDate.year, trip.departureDate.month, trip.departureDate.day);
        final rangeStart = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final rangeEnd = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        
        if (departureDate.isBefore(rangeStart) || departureDate.isAfter(rangeEnd)) {
          return true;
        }
      }
      
      // Price range filter
      if (trip.pricePerKg < _minPrice || trip.pricePerKg > _maxPrice) {
        return true;
      }
      
      // Weight range filter
      if (trip.availableWeightKg < _minWeight || trip.availableWeightKg > _maxWeight) {
        return true;
      }
      
      // Currency filter
      if (_currencyFilter != 'all' && trip.currency != _currencyFilter) {
        return true;
      }
      
      // Expired trips filter (simple check - past departure date)
      if (!_showExpiredTrips && trip.departureDate.isBefore(DateTime.now())) {
        return true;
      }
      
      return false;
    });
  }

  void _applySorting(List<Trip> trips) {
    trips.sort((a, b) {
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
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _statusFilter == filterKey;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
        onSelected: (selected) {
          setState(() {
            _statusFilter = filterKey;
            _applyFilters();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildAdvancedFilterButton() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: _showAdvancedFilters,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hasAdvancedFilters() ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hasAdvancedFilters() ? Theme.of(context).primaryColor : Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: _hasAdvancedFilters() ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 12,
                  color: _hasAdvancedFilters() ? Colors.white : Colors.grey[700],
                ),
              ),
              if (_hasAdvancedFilters())
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasAdvancedFilters() {
    return _transportFilter != 'all' ||
           _dateRange != null ||
           _minPrice > 0 ||
           _maxPrice < 1000 ||
           _minWeight > 0 ||
           _maxWeight < 1000 ||
           _currencyFilter != 'all' ||
           !_showExpiredTrips;
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 16),
            const SizedBox(width: 4),
            Text('Trier', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
      onSelected: (value) {
        setState(() {
          if (value == _sortBy) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
          _applyFilters();
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'date',
          child: Text('Date de départ'),
        ),
        const PopupMenuItem(
          value: 'destination',
          child: Text('Destination'),
        ),
        const PopupMenuItem(
          value: 'price',
          child: Text('Prix par kg'),
        ),
        const PopupMenuItem(
          value: 'capacity',
          child: Text('Capacité'),
        ),
      ],
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildAdvancedFiltersModal(),
    );
  }

  Widget _buildAdvancedFiltersModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtres avancés',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _resetAdvancedFilters();
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              
              // Filters content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transport type filter
                      _buildFilterSection(
                        'Type de transport',
                        _buildTransportFilter(setModalState),
                      ),
                      
                      // Date range filter
                      _buildFilterSection(
                        'Période',
                        _buildDateRangeFilter(setModalState),
                      ),
                      
                      // Price range filter
                      _buildFilterSection(
                        'Prix par kg',
                        _buildPriceRangeFilter(setModalState),
                      ),
                      
                      // Weight range filter
                      _buildFilterSection(
                        'Poids disponible',
                        _buildWeightRangeFilter(setModalState),
                      ),
                      
                      // Currency filter
                      _buildFilterSection(
                        'Devise',
                        _buildCurrencyFilter(setModalState),
                      ),
                      
                      // Show expired trips
                      _buildFilterSection(
                        'Options',
                        _buildOptionsFilter(setModalState),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Apply button
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: EllipsisButton.elevated(
                  onPressed: () {
                    setState(() {
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                  text: 'Appliquer les filtres',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildTransportFilter(StateSetter setModalState) {
    return Wrap(
      spacing: 8,
      children: [
        _buildModalFilterChip('Tous', 'all', _transportFilter, setModalState, (value) {
          setModalState(() => _transportFilter = value);
        }),
        _buildModalFilterChip('Avion', 'flight', _transportFilter, setModalState, (value) {
          setModalState(() => _transportFilter = value);
        }),
        _buildModalFilterChip('Voiture', 'car', _transportFilter, setModalState, (value) {
          setModalState(() => _transportFilter = value);
        }),
        _buildModalFilterChip('Train', 'train', _transportFilter, setModalState, (value) {
          setModalState(() => _transportFilter = value);
        }),
        _buildModalFilterChip('Bus', 'bus', _transportFilter, setModalState, (value) {
          setModalState(() => _transportFilter = value);
        }),
      ],
    );
  }

  Widget _buildDateRangeFilter(StateSetter setModalState) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.date_range),
          title: Text(_dateRange == null 
            ? 'Sélectionner une période' 
            : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}'),
          trailing: _dateRange != null 
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setModalState(() => _dateRange = null),
              )
            : null,
          onTap: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRange,
            );
            if (range != null) {
              setModalState(() => _dateRange = range);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPriceRangeFilter(StateSetter setModalState) {
    return Column(
      children: [
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 1000,
          divisions: 20,
          labels: RangeLabels(
            '${_minPrice.round()}€',
            '${_maxPrice.round()}€',
          ),
          onChanged: (values) {
            setModalState(() {
              _minPrice = values.start;
              _maxPrice = values.end;
            });
          },
        ),
        Text('${_minPrice.round()}€ - ${_maxPrice.round()}€'),
      ],
    );
  }

  Widget _buildWeightRangeFilter(StateSetter setModalState) {
    return Column(
      children: [
        RangeSlider(
          values: RangeValues(_minWeight, _maxWeight),
          min: 0,
          max: 1000,
          divisions: 50,
          labels: RangeLabels(
            '${_minWeight.round()}kg',
            '${_maxWeight.round()}kg',
          ),
          onChanged: (values) {
            setModalState(() {
              _minWeight = values.start;
              _maxWeight = values.end;
            });
          },
        ),
        Text('${_minWeight.round()}kg - ${_maxWeight.round()}kg'),
      ],
    );
  }

  Widget _buildCurrencyFilter(StateSetter setModalState) {
    return Wrap(
      spacing: 8,
      children: [
        _buildModalFilterChip('Toutes', 'all', _currencyFilter, setModalState, (value) {
          setModalState(() => _currencyFilter = value);
        }),
        _buildModalFilterChip('EUR', 'EUR', _currencyFilter, setModalState, (value) {
          setModalState(() => _currencyFilter = value);
        }),
        _buildModalFilterChip('CAD', 'CAD', _currencyFilter, setModalState, (value) {
          setModalState(() => _currencyFilter = value);
        }),
        _buildModalFilterChip('USD', 'USD', _currencyFilter, setModalState, (value) {
          setModalState(() => _currencyFilter = value);
        }),
      ],
    );
  }

  Widget _buildOptionsFilter(StateSetter setModalState) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Afficher les voyages expirés'),
          value: _showExpiredTrips,
          onChanged: (value) {
            setModalState(() => _showExpiredTrips = value);
          },
        ),
      ],
    );
  }

  Widget _buildModalFilterChip(
    String label, 
    String value, 
    String currentValue, 
    StateSetter setModalState,
    Function(String) onSelected,
  ) {
    final isSelected = currentValue == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        onSelected(value);
      },
      selectedColor: Theme.of(context).primaryColor,
    );
  }

  void _resetAdvancedFilters() {
    _transportFilter = 'all';
    _dateRange = null;
    _minPrice = 0;
    _maxPrice = 1000;
    _minWeight = 0;
    _maxWeight = 1000;
    _currencyFilter = 'all';
    _showExpiredTrips = true;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'statistics':
        _showStatistics();
        break;
      case 'export':
        _exportTrips();
        break;
    }
  }

  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 8),
            Text('Statistiques'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total voyages', _allTrips.length.toString()),
              _buildStatRow('Voyages publiés', _myTrips.length.toString()),
              _buildStatRow('Brouillons', _drafts.length.toString()),
              _buildStatRow('Favoris', _favorites.length.toString()),
              _buildStatRow('Nécessitent attention', _getTripsNeedingAttention().toString()),
              const Divider(),
              _buildStatRow(
                'Revenus potentiels',
                '${_allTrips.fold(0.0, (sum, trip) => sum + trip.totalEarningsPotential).toStringAsFixed(0)} CAD',
              ),
              _buildStatRow(
                'Capacité totale',
                '${_allTrips.fold(0.0, (sum, trip) => sum + trip.availableWeightKg).toStringAsFixed(1)} kg',
              ),
              const Divider(),
              _buildStatRow(
                'Voyage le plus populaire',
                _getMostPopularTrip(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getMostPopularTrip() {
    if (_allTrips.isEmpty) return 'Aucun voyage';
    
    final mostPopular = _allTrips.reduce((a, b) => 
      a.viewCount > b.viewCount ? a : b
    );
    
    return '${mostPopular.routeDisplay} (${mostPopular.viewCount} vues)';
  }
  
  int _getTripsNeedingAttention() {
    return _allTrips.where((trip) => TripStateManager.requiresAttention(trip)).length;
  }

  void _exportTrips() {
    // Simulate export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export des voyages en cours...'),
        backgroundColor: Colors.green,
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voyages exportés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}