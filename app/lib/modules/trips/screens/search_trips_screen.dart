import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_token_service.dart';
import '../models/trip_model.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/city_autocomplete_field.dart';
import '../../../widgets/ellipsis_button.dart';

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
  String? _departureCountry;
  String? _arrivalCountry;
  DateTime? _departureDate;
  DateTime? _departureDateTo;
  double? _maxPricePerKg;
  double? _minWeightKg;
  bool _verifiedOnly = false;
  bool _ticketVerifiedOnly = false;
  
  List<Trip> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isAuthenticated = false;
  String? _error;
  
  // Sorting and filtering
  // final String _sortBy = 'departure_date';
  // final bool _sortAscending = true;
  
  // Recent searches  
  // final List<Map<String, String>> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      await AuthTokenService.instance.loadToken();
      final token = AuthTokenService.instance.currentToken;
      setState(() {
        _isAuthenticated = token != null && token.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isAuthenticated = false;
      });
    }
  }

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
                        _departureCountry = country;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _swapCities,
                  icon: Icon(Icons.swap_horiz, color: Theme.of(context).primaryColor),
                  tooltip: 'Inverser départ/arrivée',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CityAutocompleteField(
                    label: 'Arrivée',
                    icon: Icons.flight_land,
                    initialValue: _arrivalCity,
                    onCitySelected: (city, country, code) {
                      setState(() {
                        _arrivalCity = city;
                        _arrivalCountry = country;
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
              child: _isLoading 
                  ? ElevatedButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Recherche...'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  : EllipsisButton.elevated(
                      onPressed: _canSearch() ? _searchTrips : null,
                      icon: const Icon(Icons.search),
                      text: 'Rechercher',
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
            ),
            
            if (_departureDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: EllipsisButton.text(
                  onPressed: () {
                    setState(() {
                      _departureDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  text: 'Effacer la date',
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
            isAuthenticated: _isAuthenticated,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Essayez d\'ajuster vos critères de recherche',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          EllipsisButton.outlined(
            onPressed: _clearSearch,
            icon: const Icon(Icons.refresh),
            text: 'Nouvelle recherche',
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          EllipsisButton.elevated(
            onPressed: _searchTrips,
            icon: const Icon(Icons.refresh),
            text: 'Réessayer',
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
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
    print('=== DEBUG: _searchTrips START ===');
    print('DEBUG: Can search: ${_canSearch()}');
    
    if (!_canSearch()) {
      print('DEBUG: Cannot search - requirements not met');
      return;
    }

    print('DEBUG: Search parameters:');
    print('  - departureCity: $_departureCity');
    print('  - arrivalCity: $_arrivalCity');
    print('  - departureCountry: $_departureCountry');
    print('  - arrivalCountry: $_arrivalCountry');
    print('  - departureDate: $_departureDate');
    print('  - departureDateFrom: ${_departureDate?.toIso8601String()}');
    print('  - maxPricePerKg: $_maxPricePerKg');
    print('  - minWeightKg: $_minWeightKg');
    print('  - verifiedOnly: $_verifiedOnly');
    print('  - ticketVerifiedOnly: $_ticketVerifiedOnly');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('DEBUG: Calling AuthTokenService.instance.tripService.searchTrips...');
      final results = await AuthTokenService.instance.tripService.searchTrips(
        departureCity: _departureCity,
        arrivalCity: _arrivalCity,
        departureCountry: _departureCountry,
        arrivalCountry: _arrivalCountry,
        departureDateFrom: _departureDate?.toIso8601String(),
        departureDateTo: _departureDateTo?.toIso8601String(),
        maxPricePerKg: _maxPricePerKg,
        minWeight: _minWeightKg,
        verifiedOnly: _verifiedOnly,
        ticketVerified: _ticketVerifiedOnly,
      );
      
      print('DEBUG: Search completed successfully');
      print('DEBUG: Results count: ${results.length}');
      print('DEBUG: Results: ${results.map((t) => '${t.id}: ${t.departureCity} → ${t.arrivalCity}').join(', ')}');
      
      setState(() {
        _searchResults = results;
        _hasSearched = true;
        _isLoading = false;
      });
      
      print('=== DEBUG: _searchTrips END - SUCCESS ===');
    } catch (e) {
      print('=== DEBUG: _searchTrips ERROR ===');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Error message: $e');
      print('DEBUG: Error toString: ${e.toString()}');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _swapCities() {
    setState(() {
      final tempCity = _departureCity;
      final tempCountry = _departureCountry;
      _departureCity = _arrivalCity;
      _departureCountry = _arrivalCountry;
      _arrivalCity = tempCity;
      _arrivalCountry = tempCountry;
    });
  }

  void _clearSearch() {
    setState(() {
      _departureCity = null;
      _arrivalCity = null;
      _departureCountry = null;
      _arrivalCountry = null;
      _departureDate = null;
      _departureDateTo = null;
      _maxPricePerKg = null;
      _minWeightKg = null;
      _verifiedOnly = false;
      _ticketVerifiedOnly = false;
      _searchResults = [];
      _hasSearched = false;
      _error = null;
    });
    _formKey.currentState?.reset();
  }
}