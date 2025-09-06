import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trip_model.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/trip_status_widget.dart';
import '../services/my_trips_state_manager.dart';
import '../../../widgets/ellipsis_button.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MyTripsStateManager _stateManager;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _stateManager = MyTripsStateManager.instance;
    
    // Écouter les changements du gestionnaire d'état
    _stateManager.addListener(_onStateChanged);
    
    // Ajouter un listener pour les changements d'onglet
    _tabController.addListener(_onTabChanged);
    
    // Charger les données initiales
    _loadInitialData();
  }

  @override
  void dispose() {
    _stateManager.removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    
    final tabIndex = _tabController.index;
    debugPrint('MyTripsScreen: Tab changed to index $tabIndex');
    
    // Charger les données de l'onglet actuel si nécessaire
    switch (tabIndex) {
      case 0:
        _stateManager.loadTripsData();
        break;
      case 1:
        _stateManager.loadDraftsData();
        break;
      case 2:
        _stateManager.loadFavoritesData();
        break;
    }
  }

  Future<void> _loadInitialData() async {
    await _stateManager.loadAllData();
  }

  Future<void> _onRefresh() async {
    await _stateManager.refreshTab(_tabController.index);
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
                    _stateManager.updateFilters(searchQuery: value);
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
                    text: 'Voyages (${_stateManager.filteredTrips.length})',
                    icon: const Icon(Icons.flight_takeoff),
                  ),
                  Tab(
                    text: 'Brouillons (${_stateManager.filteredDrafts.length})',
                    icon: const Icon(Icons.drafts),
                  ),
                  Tab(
                    text: 'Favoris (${_stateManager.filteredFavorites.length})',
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
          _buildTripsTab(
            _stateManager.filteredTrips,
            'Aucun voyage publié',
            _stateManager.isLoadingTrips,
            _stateManager.errorTrips,
            showActions: true,
          ),
          _buildTripsTab(
            _stateManager.filteredDrafts,
            'Aucun brouillon',
            _stateManager.isLoadingDrafts,
            _stateManager.errorDrafts,
            showActions: true,
          ),
          _buildTripsTab(
            _stateManager.filteredFavorites,
            'Aucun voyage favori',
            _stateManager.isLoadingFavorites,
            _stateManager.errorFavorites,
            showActions: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/create'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau voyage'),
      ),
    );
  }

  Widget _buildTripsTab(List<Trip> trips, String emptyMessage, bool isLoading, String? error, {bool showActions = true}) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return _buildErrorState(error);
    }

    if (trips.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
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
                isAuthenticated: true,
                onTap: () => context.push('/trips/${trip.id}'),
              ),
              const SizedBox(height: 8),
              TripStatusWidget(
                trip: trip,
                showDetails: false,
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

  Widget _buildErrorState(String error) {
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
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 150,
            child: ElevatedButton.icon(
              onPressed: () => _stateManager.refreshTab(_tabController.index),
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

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _stateManager.statusFilter == filterKey;
    
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
          _stateManager.updateFilters(statusFilter: filterKey);
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
            color: _stateManager.hasAdvancedFilters() ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stateManager.hasAdvancedFilters() ? Theme.of(context).primaryColor : Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: _stateManager.hasAdvancedFilters() ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 12,
                  color: _stateManager.hasAdvancedFilters() ? Colors.white : Colors.grey[700],
                ),
              ),
              if (_stateManager.hasAdvancedFilters())
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
              _stateManager.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == _stateManager.sortBy) {
          _stateManager.updateFilters(sortAscending: !_stateManager.sortAscending);
        } else {
          _stateManager.updateFilters(sortBy: value, sortAscending: true);
        }
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
                          _stateManager.resetAdvancedFilters();
                          setModalState(() {});
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
        _buildModalFilterChip('Tous', 'all', _stateManager.transportFilter, setModalState, (value) {
          _stateManager.updateFilters(transportFilter: value);
        }),
        _buildModalFilterChip('Avion', 'flight', _stateManager.transportFilter, setModalState, (value) {
          _stateManager.updateFilters(transportFilter: value);
        }),
        _buildModalFilterChip('Voiture', 'car', _stateManager.transportFilter, setModalState, (value) {
          _stateManager.updateFilters(transportFilter: value);
        }),
        _buildModalFilterChip('Train', 'train', _stateManager.transportFilter, setModalState, (value) {
          _stateManager.updateFilters(transportFilter: value);
        }),
        _buildModalFilterChip('Bus', 'bus', _stateManager.transportFilter, setModalState, (value) {
          _stateManager.updateFilters(transportFilter: value);
        }),
      ],
    );
  }

  Widget _buildDateRangeFilter(StateSetter setModalState) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.date_range),
          title: Text(_stateManager.dateRange == null 
            ? 'Sélectionner une période' 
            : '${_stateManager.dateRange!.start.day}/${_stateManager.dateRange!.start.month} - ${_stateManager.dateRange!.end.day}/${_stateManager.dateRange!.end.month}'),
          trailing: _stateManager.dateRange != null 
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _stateManager.updateFilters(dateRange: null);
                  setModalState(() {});
                },
              )
            : null,
          onTap: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _stateManager.dateRange,
            );
            if (range != null) {
              _stateManager.updateFilters(dateRange: range);
              setModalState(() {});
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
          values: RangeValues(_stateManager.minPrice, _stateManager.maxPrice),
          min: 0,
          max: 1000,
          divisions: 20,
          labels: RangeLabels(
            '${_stateManager.minPrice.round()}€',
            '${_stateManager.maxPrice.round()}€',
          ),
          onChanged: (values) {
            _stateManager.updateFilters(
              minPrice: values.start,
              maxPrice: values.end,
            );
            setModalState(() {});
          },
        ),
        Text('${_stateManager.minPrice.round()}€ - ${_stateManager.maxPrice.round()}€'),
      ],
    );
  }

  Widget _buildWeightRangeFilter(StateSetter setModalState) {
    return Column(
      children: [
        RangeSlider(
          values: RangeValues(_stateManager.minWeight, _stateManager.maxWeight),
          min: 0,
          max: 1000,
          divisions: 50,
          labels: RangeLabels(
            '${_stateManager.minWeight.round()}kg',
            '${_stateManager.maxWeight.round()}kg',
          ),
          onChanged: (values) {
            _stateManager.updateFilters(
              minWeight: values.start,
              maxWeight: values.end,
            );
            setModalState(() {});
          },
        ),
        Text('${_stateManager.minWeight.round()}kg - ${_stateManager.maxWeight.round()}kg'),
      ],
    );
  }

  Widget _buildCurrencyFilter(StateSetter setModalState) {
    return Wrap(
      spacing: 8,
      children: [
        _buildModalFilterChip('Toutes', 'all', _stateManager.currencyFilter, setModalState, (value) {
          _stateManager.updateFilters(currencyFilter: value);
        }),
        _buildModalFilterChip('EUR', 'EUR', _stateManager.currencyFilter, setModalState, (value) {
          _stateManager.updateFilters(currencyFilter: value);
        }),
        _buildModalFilterChip('CAD', 'CAD', _stateManager.currencyFilter, setModalState, (value) {
          _stateManager.updateFilters(currencyFilter: value);
        }),
        _buildModalFilterChip('USD', 'USD', _stateManager.currencyFilter, setModalState, (value) {
          _stateManager.updateFilters(currencyFilter: value);
        }),
      ],
    );
  }

  Widget _buildOptionsFilter(StateSetter setModalState) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Afficher les voyages expirés'),
          value: _stateManager.showExpiredTrips,
          onChanged: (value) {
            _stateManager.updateFilters(showExpiredTrips: value);
            setModalState(() {});
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
        setModalState(() {});
      },
      selectedColor: Theme.of(context).primaryColor,
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
    final stats = _stateManager.getStatistics();
    
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
              _buildStatRow('Total voyages', stats['totalTrips'].toString()),
              _buildStatRow('Voyages publiés', stats['publishedTrips'].toString()),
              _buildStatRow('Brouillons', stats['drafts'].toString()),
              _buildStatRow('Favoris', stats['favorites'].toString()),
              const Divider(),
              _buildStatRow(
                'Revenus potentiels',
                '${stats['totalEarnings'].toStringAsFixed(0)} CAD',
              ),
              _buildStatRow(
                'Capacité totale',
                '${stats['totalCapacity'].toStringAsFixed(1)} kg',
              ),
              const Divider(),
              _buildStatRow(
                'Voyage le plus populaire',
                stats['mostPopularTrip'].toString(),
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