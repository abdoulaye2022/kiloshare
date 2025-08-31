import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/trip_service.dart';
import '../models/trip_model.dart';
import '../widgets/city_autocomplete_field.dart';
import '../widgets/date_time_picker_field.dart';
import '../widgets/weight_slider_widget.dart';
import '../widgets/price_calculator_widget.dart';
import '../widgets/restricted_items_selector.dart';
import '../models/transport_models.dart';
import '../services/destination_validator_service.dart';
import '../../auth/services/auth_service.dart';
import '../../../widgets/auth_guard.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';

class CreateTripScreen extends StatefulWidget {
  final TransportType? initialTransportType;
  
  const CreateTripScreen({
    super.key,
    this.initialTransportType,
  });

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final PageController _pageController = PageController();
  final TripService _tripService = TripService();
  
  int _currentStep = 0;
  final int _totalSteps = 5;
  
  // Form data
  final Map<String, dynamic> _tripData = {};
  
  // Form controllers
  final _flightNumberController = TextEditingController();
  final _airlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specialNotesController = TextEditingController();
  
  bool _isLoading = false;
  PriceSuggestion? _priceSuggestion;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    // Initialize transport type if provided
    if (widget.initialTransportType != null) {
      _tripData['transport_type'] = widget.initialTransportType!.value;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flightNumberController.dispose();
    _airlineController.dispose();
    _descriptionController.dispose();
    _specialNotesController.dispose();
    super.dispose();
  }

  void _validateRoute() {
    final transportType = _tripData['transport_type'];
    final departureCity = _tripData['departure_city'];
    final departureCountry = _tripData['departure_country'];
    final arrivalCity = _tripData['arrival_city'];
    final arrivalCountry = _tripData['arrival_country'];
    
    if (transportType != null && 
        departureCity != null && 
        departureCountry != null && 
        arrivalCity != null && 
        arrivalCountry != null) {
      
      final error = DestinationValidatorService.validateRoute(
        transportType: TransportType.fromString(transportType),
        departureCity: departureCity,
        departureCountry: departureCountry,
        arrivalCity: arrivalCity,
        arrivalCountry: arrivalCountry,
      );
      
      setState(() {
        _routeError = error;
      });
      
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated || state is AuthInitial) {
          // Rediriger vers login si pas connecté
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return _buildCreateTripScreen(context);
          } else {
            // Afficher un loading pendant la vérification d'auth
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }

  Widget _buildCreateTripScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _currentStep > 0 ? _previousStep : null,
            child: const Text('Précédent'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildRouteStep(),
                _buildDateTimeStep(),
                _buildCapacityPricingStep(),
                _buildTransportDetailsStep(),
                _buildRestrictionsStep(),
              ],
            ),
          ),
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              final isCompleted = index < _currentStep;
              
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _getStepTitle(_currentStep),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Itinéraire';
      case 1: return 'Dates et heures';
      case 2: return 'Capacité et prix';
      case 3: return 'Détails du vol';
      case 4: return 'Restrictions';
      default: return '';
    }
  }

  // Step 1: Route selection
  Widget _buildRouteStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Où allez-vous ?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez vos villes de départ et d\'arrivée',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          CityAutocompleteField(
            label: 'Ville de départ',
            icon: Icons.flight_takeoff,
            initialValue: _tripData['departure_city'],
            transportType: _tripData['transport_type'] != null 
                ? TransportType.fromString(_tripData['transport_type'])
                : null,
            onCitySelected: (city, country, code) {
              setState(() {
                _tripData['departure_city'] = city;
                _tripData['departure_country'] = country;
                _tripData['departure_airport_code'] = code;
              });
              _validateRoute();
            },
          ),
          
          const SizedBox(height: 16),
          
          CityAutocompleteField(
            label: 'Ville d\'arrivée',
            icon: Icons.flight_land,
            initialValue: _tripData['arrival_city'],
            transportType: _tripData['transport_type'] != null 
                ? TransportType.fromString(_tripData['transport_type'])
                : null,
            onCitySelected: (city, country, code) {
              setState(() {
                _tripData['arrival_city'] = city;
                _tripData['arrival_country'] = country;
                _tripData['arrival_airport_code'] = code;
              });
              _validateRoute();
            },
          ),
          
          const SizedBox(height: 24),
          
          // Transport restrictions info
          if (_tripData['transport_type'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _routeError != null ? Colors.red[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _routeError != null ? Colors.red[200]! : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _routeError != null ? Icons.error_outline : Icons.info_outline,
                    color: _routeError != null ? Colors.red[700] : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _routeError ?? DestinationValidatorService.getTransportRestrictions(
                        TransportType.fromString(_tripData['transport_type'])
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: _routeError != null ? Colors.red[700] : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (_tripData['departure_city'] != null && _tripData['arrival_city'] != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.route, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_tripData['departure_city']} → ${_tripData['arrival_city']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Step 2: Date and time selection
  Widget _buildDateTimeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quand partez-vous ?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez vos dates et heures de départ et d\'arrivée',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          DateTimePickerField(
            label: 'Date et heure de départ',
            icon: Icons.flight_takeoff,
            selectedDateTime: _tripData['departure_date'],
            onDateTimeSelected: (dateTime) {
              setState(() {
                _tripData['departure_date'] = dateTime;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          DateTimePickerField(
            label: 'Date et heure d\'arrivée',
            icon: Icons.flight_land,
            selectedDateTime: _tripData['arrival_date'],
            minimumDate: _tripData['departure_date'],
            onDateTimeSelected: (dateTime) {
              setState(() {
                _tripData['arrival_date'] = dateTime;
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          if (_tripData['departure_date'] != null && _tripData['arrival_date'] != null)
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Durée du voyage',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _calculateDuration(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Step 3: Capacity and pricing
  Widget _buildCapacityPricingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacité et prix',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Définissez le poids disponible et votre prix',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          WeightSliderWidget(
            weight: _tripData['available_weight_kg']?.toDouble() ?? 10.0,
            onWeightChanged: (weight) {
              setState(() {
                _tripData['available_weight_kg'] = weight;
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          if (_canShowPriceCalculator())
            PriceCalculatorWidget(
              departureCity: _tripData['departure_city'],
              departureCountry: _tripData['departure_country'],
              arrivalCity: _tripData['arrival_city'],
              arrivalCountry: _tripData['arrival_country'],
              weightKg: _tripData['available_weight_kg']?.toDouble() ?? 10.0,
              transportType: _tripData['transport_type'] != null 
                  ? TransportType.fromString(_tripData['transport_type'])
                  : null,
              onPriceSelected: (pricePerKg, currency) {
                setState(() {
                  _tripData['price_per_kg'] = pricePerKg;
                  _tripData['currency'] = currency;
                });
              },
            ),
        ],
      ),
    );
  }

  // Step 4: Flight details
  Widget _buildTransportDetailsStep() {
    final transportType = _tripData['transport_type'];
    if (transportType == 'flight') {
      return _buildFlightDetailsStep();
    } else if (transportType == 'car') {
      return _buildCarDetailsStep();
    } else {
      return _buildGenericDetailsStep();
    }
  }

  Widget _buildFlightDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails du vol',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informations supplémentaires sur votre vol (optionnel)',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _flightNumberController,
            decoration: const InputDecoration(
              labelText: 'Numéro de vol',
              hintText: 'Ex: AF1234',
              prefixIcon: Icon(Icons.confirmation_number),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _airlineController,
            decoration: const InputDecoration(
              labelText: 'Compagnie aérienne',
              hintText: 'Ex: Air France',
              prefixIcon: Icon(Icons.airplane_ticket),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description du voyage',
              hintText: 'Décrivez votre voyage, vos disponibilités...',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _specialNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes spéciales',
              hintText: 'Conditions particulières, instructions...',
              prefixIcon: Icon(Icons.note_add),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails du voyage en voiture',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informations sur votre voyage en voiture',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description du voyage',
              hintText: 'Décrivez votre trajet, vos disponibilités...',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _specialNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes spéciales',
              hintText: 'Instructions particulières pour la remise...',
              prefixIcon: Icon(Icons.note_add),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Précisez où et comment vous comptez récupérer et livrer les colis durant votre trajet.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails du voyage',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informations supplémentaires sur votre voyage',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description du voyage',
              hintText: 'Décrivez votre voyage...',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _specialNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes spéciales',
              hintText: 'Instructions particulières...',
              prefixIcon: Icon(Icons.note_add),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // Step 5: Restrictions
  Widget _buildRestrictionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objets interdits',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez les objets que vous n\'acceptez pas',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          RestrictedItemsSelector(
            selectedCategories: _tripData['restricted_categories'] ?? [],
            selectedItems: _tripData['restricted_items'] ?? [],
            onSelectionChanged: (categories, items) {
              setState(() {
                _tripData['restricted_categories'] = categories;
                _tripData['restricted_items'] = items;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Vous pourrez toujours modifier ces restrictions après la publication.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                child: const Text('Précédent'),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            flex: _currentStep > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isLoading || !_canContinue() ? null : _nextStep,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_currentStep < _totalSteps - 1 ? 'Suivant' : 'Créer le voyage'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canContinue() {
    switch (_currentStep) {
      case 0: // Route
        return _tripData['departure_city'] != null && 
               _tripData['arrival_city'] != null &&
               _tripData['departure_city'] != _tripData['arrival_city'];
      case 1: // Dates
        return _tripData['departure_date'] != null && 
               _tripData['arrival_date'] != null;
      case 2: // Capacity and pricing
        return _tripData['available_weight_kg'] != null &&
               _tripData['price_per_kg'] != null;
      case 3: // Flight details (all optional)
        return true;
      case 4: // Restrictions (optional)
        return true;
      default:
        return false;
    }
  }

  bool _canShowPriceCalculator() {
    return _tripData['departure_city'] != null &&
           _tripData['arrival_city'] != null &&
           _tripData['departure_country'] != null &&
           _tripData['arrival_country'] != null;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createTrip();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _calculateDuration() {
    if (_tripData['departure_date'] == null || _tripData['arrival_date'] == null) {
      return '';
    }
    
    final departure = _tripData['departure_date'] as DateTime;
    final arrival = _tripData['arrival_date'] as DateTime;
    final duration = arrival.difference(departure);
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}';
    } else {
      return '${minutes}min';
    }
  }

  Future<void> _createTrip() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _tripService.createTrip(
        transportType: _tripData['transport_type'],
        departureCity: _tripData['departure_city'],
        departureCountry: _tripData['departure_country'],
        departureAirportCode: _tripData['departure_airport_code'],
        departureDate: _tripData['departure_date'],
        arrivalCity: _tripData['arrival_city'],
        arrivalCountry: _tripData['arrival_country'],
        arrivalAirportCode: _tripData['arrival_airport_code'],
        arrivalDate: _tripData['arrival_date'],
        availableWeightKg: _tripData['available_weight_kg'].toDouble(),
        pricePerKg: _tripData['price_per_kg'].toDouble(),
        currency: _tripData['currency'] ?? 'CAD',
        flightNumber: _flightNumberController.text.trim().isEmpty 
            ? null : _flightNumberController.text.trim(),
        airline: _airlineController.text.trim().isEmpty 
            ? null : _airlineController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null : _descriptionController.text.trim(),
        specialNotes: _specialNotesController.text.trim().isEmpty 
            ? null : _specialNotesController.text.trim(),
        restrictedCategories: _tripData['restricted_categories'],
        restrictedItems: _tripData['restricted_items'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voyage créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  } // fin de _buildCreateTripScreen
}