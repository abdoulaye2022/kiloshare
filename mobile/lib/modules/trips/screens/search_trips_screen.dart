import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_token_service.dart';
import '../models/trip_model.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/city_autocomplete_field.dart';
import '../../../widgets/auth_guard.dart';

class SearchTripsScreen extends StatefulWidget {
  const SearchTripsScreen({super.key});

  @override
  State<SearchTripsScreen> createState() => _SearchTripsScreenState();
}

class _SearchTripsScreenState extends State<SearchTripsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Search parameters
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _departureDate;
  double? _maxPricePerKg;
  double? _minWeightKg;
  
  List<Trip> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _buildSearchForm(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Où souhaitez-vous voyager ?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Departure and arrival cities
            Row(
              children: [
                Expanded(
                  child: CityAutocompleteField(
                    label: 'Départ',
                    icon: Icons.flight_takeoff,
                    initialValue: _departureCity,
                    onCitySelected: (city, country, code) {
                      setState(() {
                        _departureCity = city;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CityAutocompleteField(
                    label: 'Arrivée',
                    icon: Icons.flight_land,
                    initialValue: _arrivalCity,
                    onCitySelected: (city, country, code) {
                      setState(() {
                        _arrivalCity = city;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Departure date
            InkWell(
              onTap: _selectDepartureDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de départ (optionnel)',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _departureDate != null
                      ? '${_departureDate!.day}/${_departureDate!.month}/${_departureDate!.year}'
                      : 'Sélectionner une date',
                  style: TextStyle(
                    color: _departureDate != null 
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Advanced filters (collapsible)
            ExpansionTile(
              title: const Text('Filtres avancés'),
              leading: const Icon(Icons.filter_list),
              children: [
                const SizedBox(height: 8),
                
                // Max price filter
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Prix maximum par kg (CAD \$)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    helperText: 'Laissez vide pour ne pas filtrer',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _maxPricePerKg = double.tryParse(value);
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Min weight filter
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Poids minimum disponible (kg)',
                    prefixIcon: Icon(Icons.luggage),
                    border: OutlineInputBorder(),
                    helperText: 'Laissez vide pour ne pas filtrer',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _minWeightKg = double.tryParse(value);
                    });
                  },
                ),
                
                const SizedBox(height: 16),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Search button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSearch() ? _searchTrips : null,
                icon: _isLoading 
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Recherche...' : 'Rechercher'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            if (_departureDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _departureDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Effacer la date'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recherche en cours...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (!_hasSearched) {
      return _buildInitialState();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyResultsState();
    }

    return RefreshIndicator(
      onRefresh: _searchTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length + 1, // +1 for results header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildResultsHeader();
          }
          
          final trip = _searchResults[index - 1];
          return TripCardWidget(
            trip: trip,
            onTap: () => context.push('/trips/${trip.id}'),
          );
        },
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '${_searchResults.length} voyage${_searchResults.length > 1 ? 's' : ''} trouvé${_searchResults.length > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Recherchez votre voyage idéal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Renseignez au moins une ville de départ ou d\'arrivée',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsState() {
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
            'Aucun voyage trouvé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez d\'ajuster vos critères de recherche',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.refresh),
            label: const Text('Nouvelle recherche'),
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
            'Erreur de recherche',
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
            onPressed: _searchTrips,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  bool _canSearch() {
    return (_departureCity != null && _departureCity!.isNotEmpty) ||
           (_arrivalCity != null && _arrivalCity!.isNotEmpty);
  }

  Future<void> _selectDepartureDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _departureDate = date;
      });
    }
  }

  Future<void> _searchTrips() async {
    if (!_canSearch()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await AuthTokenService.instance.tripService.searchTrips(
        departureCity: _departureCity,
        arrivalCity: _arrivalCity,
        departureDateFrom: _departureDate?.toIso8601String(),
        maxPricePerKg: _maxPricePerKg,
        minWeight: _minWeightKg,
      );
      
      setState(() {
        _searchResults = results;
        _hasSearched = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _departureCity = null;
      _arrivalCity = null;
      _departureDate = null;
      _maxPricePerKg = null;
      _minWeightKg = null;
      _searchResults = [];
      _hasSearched = false;
      _error = null;
    });
    _formKey.currentState?.reset();
  }
}