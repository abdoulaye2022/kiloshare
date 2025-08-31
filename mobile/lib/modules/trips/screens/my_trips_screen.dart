import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_token_service.dart';
import '../models/trip_model.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/trip_status_widget.dart';
import '../services/trip_state_manager.dart';
import '../services/trip_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final trips = await AuthTokenService.instance.tripService.getUserTrips();
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
        favorites = await _tripService.getFavorites();
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
                  ],
                ),
              ),
              
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(
                    text: 'Mes voyages (${_filteredTrips.length})',
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
          ElevatedButton.icon(
            onPressed: () => context.push('/trips/create'),
            icon: const Icon(Icons.add),
            label: const Text('Créer un voyage'),
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
          ElevatedButton.icon(
            onPressed: _loadTrips,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    List<Trip> filteredPublished = List.from(_myTrips);
    List<Trip> filteredDrafts = List.from(_drafts);

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
      
      List<Trip> filteredFavs = List.from(_favorites);
      filteredFavs = filteredFavs.where((trip) => 
        trip.departureCity.toLowerCase().contains(query) ||
        trip.arrivalCity.toLowerCase().contains(query) ||
        (trip.flightNumber?.toLowerCase().contains(query) ?? false) ||
        (trip.airline?.toLowerCase().contains(query) ?? false)
      ).toList();
      _filteredFavorites = filteredFavs;
    }

    // Apply sorting
    _applySorting(filteredPublished);
    _applySorting(filteredDrafts);
    _applySorting(_filteredFavorites);

    setState(() {
      _filteredTrips = filteredPublished;
      _filteredDrafts = filteredDrafts;
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