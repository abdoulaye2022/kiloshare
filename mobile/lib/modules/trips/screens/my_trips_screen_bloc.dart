import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../bloc/trip_bloc.dart';
import '../models/trip_model.dart';
import '../widgets/trip_status_widget.dart';

class MyTripsScreenBloc extends StatelessWidget {
  const MyTripsScreenBloc({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TripBloc(),
      child: const _MyTripsView(),
    );
  }
}

class _MyTripsView extends StatefulWidget {
  const _MyTripsView();

  @override
  State<_MyTripsView> createState() => _MyTripsViewState();
}

class _MyTripsViewState extends State<_MyTripsView> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filter state
  String _statusFilter = 'all';
  String _transportFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minPrice;
  double? _maxPrice;
  
  // Controllers for price inputs
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Load initial data for the first tab immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<TripBloc>();
        bloc.add(const LoadTrips());
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final bloc = context.read<TripBloc>();
    
    switch (_tabController.index) {
      case 0: // All trips
        bloc.add(const LoadTrips());
        break;
      case 1: // Drafts
        bloc.add(const LoadDrafts());
        break;
      case 2: // Favorites
        bloc.add(const LoadFavorites());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes voyages'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tous', icon: Icon(Icons.list)),
            Tab(text: 'Brouillons', icon: Icon(Icons.drafts)),
            Tab(text: 'Favoris', icon: Icon(Icons.favorite)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create trip screen
              context.push('/trips/create');
            },
          ),
        ],
      ),
      body: BlocConsumer<TripBloc, TripState>(
        listener: (context, state) {
          if (state is TripActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TripError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is TripDuplicated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voyage dupliqué avec succès'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TripDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voyage supprimé avec succès'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTripsTab(context, state), // All trips
              _buildDraftsTab(context, state), // Drafts
              _buildFavoritesTab(context, state), // Favorites
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripsTab(BuildContext context, TripState state) {
    if (state is TripLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is TripError) {
      return _buildErrorView(context, state.message, () {
        context.read<TripBloc>().add(const LoadTrips());
      });
    }

    if (state is TripsLoaded) {
      if (state.trips.isEmpty) {
        return _buildEmptyView(
          context,
          'Aucun voyage',
          'Vous n\'avez pas encore créé de voyages.',
          Icons.flight_takeoff,
        );
      }
      return _buildTripsList(context, state.trips);
    }

    // Initial state - trigger loading if not already loading
    if (state is TripInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TripBloc>().add(const LoadTrips());
        }
      });
      return const Center(child: CircularProgressIndicator());
    }

    return _buildEmptyView(
      context,
      'Aucun voyage',
      'Vous n\'avez pas encore créé de voyages.',
      Icons.flight_takeoff,
    );
  }

  Widget _buildDraftsTab(BuildContext context, TripState state) {
    if (state is TripLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is TripError) {
      return _buildErrorView(context, state.message, () {
        context.read<TripBloc>().add(const LoadDrafts());
      });
    }

    if (state is DraftsLoaded) {
      if (state.drafts.isEmpty) {
        return _buildEmptyView(
          context,
          'Aucun brouillon',
          'Vous n\'avez pas de brouillons de voyages.',
          Icons.drafts,
        );
      }
      return _buildTripsList(context, state.drafts);
    }

    return _buildEmptyView(
      context,
      'Aucun brouillon',
      'Vous n\'avez pas de brouillons de voyages.',
      Icons.drafts,
    );
  }

  Widget _buildFavoritesTab(BuildContext context, TripState state) {
    if (state is TripLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is TripError) {
      return _buildErrorView(context, state.message, () {
        context.read<TripBloc>().add(const LoadFavorites());
      });
    }

    if (state is FavoritesLoaded) {
      if (state.favorites.isEmpty) {
        return _buildEmptyView(
          context,
          'Aucun favori',
          'Vous n\'avez pas encore de voyages favoris.',
          Icons.favorite_border,
        );
      }
      return _buildTripsList(context, state.favorites);
    }

    return _buildEmptyView(
      context,
      'Aucun favori',
      'Vous n\'avez pas encore de voyages favoris.',
      Icons.favorite_border,
    );
  }

  Widget _buildTripsList(BuildContext context, List<Trip> trips) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh based on current tab
        final bloc = context.read<TripBloc>();
        switch (_tabController.index) {
          case 0:
            bloc.add(const RefreshTrips());
            break;
          case 1:
            bloc.add(const LoadDrafts());
            break;
          case 2:
            bloc.add(const LoadFavorites());
            break;
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          return _buildTripCard(context, trip);
        },
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          context.push('/trips/${trip.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with route info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.departureCity} → ${trip.arrivalCity}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${trip.departureCountry} → ${trip.arrivalCountry}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip.pricePerKg.toStringAsFixed(0)} ${trip.currency}/kg',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        '${trip.availableWeightKg.toStringAsFixed(0)} kg',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Status widget
              TripStatusWidget(trip: trip),
              
              const SizedBox(height: 12),
              
              // Date and basic info
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    _formatTripDates(trip.departureDate.toLocal(), trip.arrivalDate.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (trip.viewCount > 0) ...[
                    Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.viewCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context, String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtrer les voyages',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Réinitialiser'),
                    ),
                  ],
                ),
              ),
              
              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status filter
                      _buildFilterSection(
                        context,
                        'Statut',
                        [
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildStatusFilterChip('Tous', 'all'),
                              _buildStatusFilterChip('Actifs', 'active'),
                              _buildStatusFilterChip('En pause', 'paused'),
                              _buildStatusFilterChip('En attente', 'pending'),
                              _buildStatusFilterChip('Terminés', 'completed'),
                              _buildStatusFilterChip('Annulés', 'cancelled'),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Transport type filter
                      _buildFilterSection(
                        context,
                        'Type de transport',
                        [
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildTransportFilterChip('Tous', 'all'),
                              _buildTransportFilterChip('Avion', 'flight'),
                              _buildTransportFilterChip('Train', 'train'),
                              _buildTransportFilterChip('Bus', 'bus'),
                              _buildTransportFilterChip('Voiture', 'car'),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Date range
                      _buildFilterSection(
                        context,
                        'Date de départ',
                        [
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Du'),
                            subtitle: Text(_startDate != null 
                                ? DateFormat('dd/MM/yyyy').format(_startDate!) 
                                : 'Sélectionner une date'),
                            onTap: () => _selectStartDate(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Au'),
                            subtitle: Text(_endDate != null 
                                ? DateFormat('dd/MM/yyyy').format(_endDate!) 
                                : 'Sélectionner une date'),
                            onTap: () => _selectEndDate(context),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Price range
                      Text(
                        'Gamme de prix (€/kg)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Min',
                                border: OutlineInputBorder(),
                                prefixText: 'CAD ',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _minPrice = double.tryParse(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Max',
                                border: OutlineInputBorder(),
                                prefixText: 'CAD ',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _maxPrice = double.tryParse(value);
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              
              // Apply button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilters();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Appliquer les filtres'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  // Filter chip builders
  Widget _buildStatusFilterChip(String label, String status) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          _statusFilter = status;
        });
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildTransportFilterChip(String label, String transport) {
    final isSelected = _transportFilter == transport;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          _transportFilter = transport;
        });
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
    );
  }

  // Date selection methods
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Sélectionnez la date de début',
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, clear it
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Sélectionnez la date de fin',
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  // Filter management methods
  void _resetFilters() {
    setState(() {
      _statusFilter = 'all';
      _transportFilter = 'all';
      _startDate = null;
      _endDate = null;
      _minPrice = null;
      _maxPrice = null;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  void _applyFilters() {
    // Build filter map
    final filters = <String, dynamic>{};
    
    if (_statusFilter != 'all') {
      filters['status'] = _statusFilter;
    }
    
    if (_transportFilter != 'all') {
      filters['transport_type'] = _transportFilter;
    }
    
    if (_startDate != null) {
      filters['departure_date_from'] = DateFormat('yyyy-MM-dd').format(_startDate!);
    }
    
    if (_endDate != null) {
      filters['departure_date_to'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    }
    
    if (_minPrice != null) {
      filters['min_price_per_kg'] = _minPrice;
    }
    
    if (_maxPrice != null) {
      filters['max_price_per_kg'] = _maxPrice;
    }

    // Apply filters via BLoC using the new filter events
    final bloc = context.read<TripBloc>();
    switch (_tabController.index) {
      case 0: // All trips
        bloc.add(FilterUserTrips(filters));
        break;
      case 1: // Drafts
        bloc.add(FilterDrafts(filters));
        break;
      case 2: // Favorites
        bloc.add(FilterFavorites(filters));
        break;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filtres appliqués !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTripDates(DateTime departureLocal, DateTime arrivalLocal) {
    final formatter = DateFormat('dd/MM');
    final yearFormatter = DateFormat('dd/MM/yyyy');
    
    if (departureLocal.day == arrivalLocal.day &&
        departureLocal.month == arrivalLocal.month &&
        departureLocal.year == arrivalLocal.year) {
      return yearFormatter.format(departureLocal);
    } else {
      return '${formatter.format(departureLocal)} - ${formatter.format(arrivalLocal)}';
    }
  }
}