import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/trip_service.dart';
import '../widgets/city_autocomplete_field.dart';
import '../widgets/date_time_picker_field.dart';
import '../widgets/weight_slider_widget.dart';
import '../widgets/price_calculator_widget.dart';
import '../widgets/restricted_items_selector.dart';
import '../widgets/trip_image_picker.dart';
import '../models/transport_models.dart';
import '../services/destination_validator_service.dart';
import '../services/trip_image_service.dart';
import '../../../widgets/ellipsis_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';
import 'dart:io';

class CreateTripScreen extends StatefulWidget {
  final TransportType? initialTransportType;
  final String? tripId; // For edit mode

  const CreateTripScreen({
    super.key,
    this.initialTransportType,
    this.tripId,
  });

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final PageController _pageController = PageController();
  final TripService _tripService = TripService();

  int _currentStep = 0;
  final int _totalSteps = 6;

  // Form data
  final Map<String, dynamic> _tripData = {};

  // Images
  List<File> _selectedImages = [];
  List<TripImage> _existingImages = [];
  final TripImageService _tripImageService = TripImageService();

  // Form controllers
  final _flightNumberController = TextEditingController();
  final _airlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specialNotesController = TextEditingController();

  bool _isLoading = false;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    // Initialize transport type if provided
    if (widget.initialTransportType != null) {
      _tripData['transport_type'] = widget.initialTransportType!.value;
    }

    // Load trip data if in edit mode
    if (widget.tripId != null) {
      _loadTripForEdit();
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

  Future<void> _loadTripForEdit() async {
    if (widget.tripId == null) return;

    setState(() => _isLoading = true);

    try {
      final trip = await _tripService.getTripById(widget.tripId!);

      // Populate form data
      setState(() {
        _tripData.addAll({
          'transport_type': trip.transportType,
          'departure_city': trip.departureCity,
          'departure_country': trip.departureCountry,
          'departure_airport_code': trip.departureAirportCode,
          'arrival_city': trip.arrivalCity,
          'arrival_country': trip.arrivalCountry,
          'arrival_airport_code': trip.arrivalAirportCode,
          'departure_date': trip.departureDate,
          'departure_time': TimeOfDay.fromDateTime(trip.departureDate),
          'arrival_date': trip.arrivalDate,
          'arrival_time': TimeOfDay.fromDateTime(trip.arrivalDate),
          'available_weight_kg': trip.availableWeightKg,
          'price_per_kg': trip.pricePerKg,
          'currency': trip.currency,
          'description': trip.description ?? '',
          'special_notes': trip.specialNotes ?? '',
          'restricted_items': trip.restrictedItems ?? [],
          'restricted_categories': trip.restrictedCategories ?? [],
          'restriction_notes': trip.restrictionNotes ?? '',
        });

        // Debug logging for restrictions
        print('CreateTripScreen: Loaded trip restrictions:');
        print('  restricted_categories: ${trip.restrictedCategories}');
        print('  restricted_items: ${trip.restrictedItems}');
        print('  restriction_notes: ${trip.restrictionNotes}');
        print(
            '  _tripData restricted_categories: ${_tripData['restricted_categories']}');
        print('  _tripData restricted_items: ${_tripData['restricted_items']}');

        // Update text controllers
        _flightNumberController.text = trip.flightNumber ?? '';
        _airlineController.text = trip.airline ?? '';
        _descriptionController.text = trip.description ?? '';
        _specialNotesController.text = trip.specialNotes ?? '';
      });

      // Load existing images
      try {
        final images = await _tripImageService.getTripImages(widget.tripId!);
        setState(() {
          _existingImages = images;
        });
      } catch (e) {
        print('Warning: Failed to load trip images: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du voyage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        title:
            Text(widget.tripId != null ? 'Modifier voyage' : 'Créer un voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          EllipsisButton.text(
            onPressed: _currentStep > 0 ? _previousStep : null,
            text: 'Précédent',
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
                _buildImagesStep(),
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
      case 0:
        return 'Itinéraire';
      case 1:
        return 'Dates et heures';
      case 2:
        return 'Capacité et prix';
      case 3:
        return _tripData['transport_type'] == 'flight'
            ? 'Détails du vol'
            : _tripData['transport_type'] == 'car'
                ? 'Détails du voyage'
                : 'Détails du transport';
      case 4:
        return 'Restrictions';
      default:
        return '';
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

          // Transport type selection (especially useful in edit mode)
          _buildTransportTypeSelector(),

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
                  color: _routeError != null
                      ? Colors.red[200]!
                      : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _routeError != null
                        ? Icons.error_outline
                        : Icons.info_outline,
                    color: _routeError != null
                        ? Colors.red[700]
                        : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _routeError ??
                          DestinationValidatorService.getTransportRestrictions(
                              TransportType.fromString(
                                  _tripData['transport_type'])),
                      style: TextStyle(
                        fontSize: 13,
                        color: _routeError != null
                            ? Colors.red[700]
                            : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_tripData['departure_city'] != null &&
              _tripData['arrival_city'] != null)
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

  // Transport type selector widget
  Widget _buildTransportTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Moyen de transport',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTransportOption(
                    transportType: TransportType.flight,
                    icon: Icons.flight,
                    label: 'Avion',
                    description: 'Vol commercial',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTransportOption(
                    transportType: TransportType.car,
                    icon: Icons.directions_car,
                    label: 'Voiture',
                    description: 'Route terrestre',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportOption({
    required TransportType transportType,
    required IconData icon,
    required String label,
    required String description,
  }) {
    final isSelected = _tripData['transport_type'] == transportType.value;

    return InkWell(
      onTap: () {
        setState(() {
          _tripData['transport_type'] = transportType.value;
          // Reset airport codes when changing transport type
          if (transportType != TransportType.flight) {
            _tripData['departure_airport_code'] = null;
            _tripData['arrival_airport_code'] = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          if (_tripData['departure_date'] != null &&
              _tripData['arrival_date'] != null)
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
            weight: (_tripData['available_weight_kg'] ?? 10.0).toDouble(),
            onWeightChanged: (weight) {
              print('DEBUG: Weight changed to: $weight');
              setState(() {
                _tripData['available_weight_kg'] = weight;
                print('DEBUG: _tripData after weight change: $_tripData');
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
              weightKg: (_tripData['available_weight_kg'] ?? 10.0).toDouble(),
              transportType: _tripData['transport_type'] != null
                  ? TransportType.fromString(_tripData['transport_type'])
                  : null,
              onPriceSelected: (pricePerKg, currency) {
                print(
                    'DEBUG: Price selected - pricePerKg: $pricePerKg, currency: $currency');
                setState(() {
                  _tripData['price_per_kg'] = pricePerKg;
                  _tripData['currency'] = currency;
                  print('DEBUG: _tripData after price selection: $_tripData');
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

  Widget _buildImagesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos de l\'annonce',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des photos pour rendre votre annonce plus attractive et gagner la confiance des expéditeurs.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          TripImagePicker(
            initialImages: _selectedImages,
            existingImages: _existingImages,
            onImagesChanged: (images) {
              setState(() {
                _selectedImages = images;
              });
            },
            onDeleteExisting: widget.tripId != null
                ? (image) async {
                    try {
                      await _tripImageService.deleteTripImage(
                          widget.tripId!, image.id);
                      setState(() {
                        _existingImages
                            .removeWhere((img) => img.id == image.id);
                      });
                      _showSnackBar(
                          'Photo supprimée avec succès', Colors.green);
                    } catch (e) {
                      _showSnackBar(
                          'Erreur lors de la suppression: $e', Colors.red);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Les photos seront visibles après approbation par notre équipe. Assurez-vous qu\'elles sont claires et respectent nos conditions d\'utilisation.',
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
              child: EllipsisButton.outlined(
                onPressed: _isLoading ? null : _previousStep,
                text: 'Précédent',
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep > 0 ? 1 : 2,
            child: _isLoading
                ? ElevatedButton(
                    onPressed: null,
                    child: const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : EllipsisButton.elevated(
                    onPressed: !_canContinue() ? null : _nextStep,
                    text: _currentStep < _totalSteps - 1
                        ? 'Suivant'
                        : (widget.tripId != null
                            ? 'Modifier l\'annonce'
                            : 'Créer l\'annonce'),
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
      case 5: // Images (optional)
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
    print('=== DEBUG _nextStep called ===');
    print('Current step: $_currentStep');
    print('Total steps: $_totalSteps');
    print('Can continue: ${_canContinue()}');

    if (_currentStep < _totalSteps - 1) {
      print('Moving to next step');
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      print('Last step reached, calling _submitTrip()');
      _submitTrip();
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
    if (_tripData['departure_date'] == null ||
        _tripData['arrival_date'] == null) {
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

  Future<void> _submitTrip() async {
    print('=== DEBUG: _submitTrip() START ===');
    print('DEBUG: _tripData full contents: $_tripData');
    print('DEBUG: _tripData keys: ${_tripData.keys.toList()}');
    print('DEBUG: _tripData is null: ${_tripData == null}');

    // Debug each key access that might be null
    print('DEBUG: Checking individual keys...');
    print(
        'DEBUG: transport_type: ${_tripData['transport_type']} (type: ${_tripData['transport_type']?.runtimeType})');
    print(
        'DEBUG: departure_city: ${_tripData['departure_city']} (type: ${_tripData['departure_city']?.runtimeType})');
    print(
        'DEBUG: departure_country: ${_tripData['departure_country']} (type: ${_tripData['departure_country']?.runtimeType})');
    print(
        'DEBUG: arrival_city: ${_tripData['arrival_city']} (type: ${_tripData['arrival_city']?.runtimeType})');
    print(
        'DEBUG: arrival_country: ${_tripData['arrival_country']} (type: ${_tripData['arrival_country']?.runtimeType})');
    print(
        'DEBUG: departure_date: ${_tripData['departure_date']} (type: ${_tripData['departure_date']?.runtimeType})');
    print(
        'DEBUG: arrival_date: ${_tripData['arrival_date']} (type: ${_tripData['arrival_date']?.runtimeType})');
    print(
        'DEBUG: available_weight_kg: ${_tripData['available_weight_kg']} (type: ${_tripData['available_weight_kg']?.runtimeType})');
    print(
        'DEBUG: price_per_kg: ${_tripData['price_per_kg']} (type: ${_tripData['price_per_kg']?.runtimeType})');
    print(
        'DEBUG: currency: ${_tripData['currency']} (type: ${_tripData['currency']?.runtimeType})');
    print(
        'DEBUG: departure_airport_code: ${_tripData['departure_airport_code']} (type: ${_tripData['departure_airport_code']?.runtimeType})');
    print(
        'DEBUG: arrival_airport_code: ${_tripData['arrival_airport_code']} (type: ${_tripData['arrival_airport_code']?.runtimeType})');
    print(
        'DEBUG: restricted_categories: ${_tripData['restricted_categories']} (type: ${_tripData['restricted_categories']?.runtimeType})');
    print(
        'DEBUG: restricted_items: ${_tripData['restricted_items']} (type: ${_tripData['restricted_items']?.runtimeType})');

    // Debug controllers
    print(
        'DEBUG: _descriptionController.text: "${_descriptionController.text}"');
    print(
        'DEBUG: _specialNotesController.text: "${_specialNotesController.text}"');
    print(
        'DEBUG: _flightNumberController.text: "${_flightNumberController.text}"');
    print('DEBUG: _airlineController.text: "${_airlineController.text}"');

    setState(() {
      _isLoading = true;
    });

    try {
      final isEditMode = widget.tripId != null;
      print('DEBUG: isEditMode: $isEditMode');

      if (isEditMode) {
        // Edit existing trip
        print('DEBUG: Creating updateData for edit mode...');
        late final Map<String, dynamic> updateData;
        try {
          updateData = {
            'transport_type': _tripData['transport_type'],
            'departure_city': _tripData['departure_city'],
            'departure_country': _tripData['departure_country'],
            'departure_date': _tripData['departure_date']?.toIso8601String(),
            'arrival_city': _tripData['arrival_city'],
            'arrival_country': _tripData['arrival_country'],
            'arrival_date': _tripData['arrival_date']?.toIso8601String(),
            'available_weight_kg': _tripData['available_weight_kg']?.toDouble(),
            'price_per_kg': _tripData['price_per_kg']?.toDouble(),
            'currency': _tripData['currency'] ?? 'CAD',
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            'special_notes': _specialNotesController.text.trim().isEmpty
                ? null
                : _specialNotesController.text.trim(),
            'restricted_categories':
                (_tripData['restricted_categories'] as List?)?.isEmpty == false
                    ? _tripData['restricted_categories']
                    : null,
            'restricted_items':
                (_tripData['restricted_items'] as List?)?.isEmpty == false
                    ? _tripData['restricted_items']
                    : null,
          };
          print('DEBUG: updateData created successfully: $updateData');
        } catch (e) {
          print('DEBUG: ERROR creating updateData: $e');
          print('DEBUG: Error type: ${e.runtimeType}');
          rethrow;
        }

        // Add flight-specific fields only for flight transport
        if (_tripData['transport_type'] == 'flight') {
          updateData.addAll({
            'departure_airport_code': _tripData['departure_airport_code'],
            'arrival_airport_code': _tripData['arrival_airport_code'],
            'flight_number': _flightNumberController.text.trim().isEmpty
                ? null
                : _flightNumberController.text.trim(),
            'airline': _airlineController.text.trim().isEmpty
                ? null
                : _airlineController.text.trim(),
          });
        } else {
          // For non-flight transport, explicitly set airport codes to null
          updateData.addAll({
            'departure_airport_code': null,
            'arrival_airport_code': null,
            'flight_number': null,
            'airline': null,
          });
        }

        await _tripService.updateTrip(widget.tripId!, updateData);

        // Upload images if any selected
        if (_selectedImages.isNotEmpty) {
          try {
            await _tripImageService.uploadTripImages(
                widget.tripId!, _selectedImages);
          } catch (e) {
            print('Warning: Image upload failed: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voyage modifié avec succès !'),
              backgroundColor: Colors.green,
            ),
          );

          context.pop(); // Go back to trip details
        }
      } else {
        // Create new trip
        print('DEBUG: Creating new trip...');
        try {
          print('DEBUG: About to call _tripService.createTrip with:');
          print('DEBUG: transportType: ${_tripData['transport_type']}');
          print('DEBUG: departureCity: ${_tripData['departure_city']}');
          print('DEBUG: departureCountry: ${_tripData['departure_country']}');
          print(
              'DEBUG: departureAirportCode: ${_tripData['transport_type'] == 'flight' ? _tripData['departure_airport_code'] : null}');
          print('DEBUG: departureDate: ${_tripData['departure_date']}');
          print('DEBUG: arrivalCity: ${_tripData['arrival_city']}');
          print('DEBUG: arrivalCountry: ${_tripData['arrival_country']}');
          print(
              'DEBUG: arrivalAirportCode: ${_tripData['transport_type'] == 'flight' ? _tripData['arrival_airport_code'] : null}');
          print('DEBUG: arrivalDate: ${_tripData['arrival_date']}');
          print(
              'DEBUG: availableWeightKg: ${(_tripData['available_weight_kg'] ?? 0).toDouble()}');
          print(
              'DEBUG: pricePerKg: ${(_tripData['price_per_kg'] ?? 0).toDouble()}');
          print('DEBUG: currency: ${_tripData['currency'] ?? 'CAD'}');
          print(
              'DEBUG: restrictedCategories: ${(_tripData['restricted_categories'] as List?)?.isEmpty == false ? List<String>.from(_tripData['restricted_categories']) : null}');
          print(
              'DEBUG: restrictedItems: ${(_tripData['restricted_items'] as List?)?.isEmpty == false ? List<String>.from(_tripData['restricted_items']) : null}');

          final createdTrip = await _tripService.createTrip(
            transportType: _tripData['transport_type'],
            departureCity: _tripData['departure_city'],
            departureCountry: _tripData['departure_country'],
            departureAirportCode: _tripData['transport_type'] == 'flight'
                ? _tripData['departure_airport_code']
                : null,
            departureDate: _tripData['departure_date'],
            arrivalCity: _tripData['arrival_city'],
            arrivalCountry: _tripData['arrival_country'],
            arrivalAirportCode: _tripData['transport_type'] == 'flight'
                ? _tripData['arrival_airport_code']
                : null,
            arrivalDate: _tripData['arrival_date'],
            availableWeightKg:
                (_tripData['available_weight_kg'] ?? 0).toDouble(),
            pricePerKg: (_tripData['price_per_kg'] ?? 0).toDouble(),
            currency: _tripData['currency'] ?? 'CAD',
            flightNumber: _tripData['transport_type'] == 'flight' &&
                    !_flightNumberController.text.trim().isEmpty
                ? _flightNumberController.text.trim()
                : null,
            airline: _tripData['transport_type'] == 'flight' &&
                    !_airlineController.text.trim().isEmpty
                ? _airlineController.text.trim()
                : null,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            specialNotes: _specialNotesController.text.trim().isEmpty
                ? null
                : _specialNotesController.text.trim(),
            restrictedCategories:
                (_tripData['restricted_categories'] as List?)?.isEmpty == false
                    ? List<String>.from(_tripData['restricted_categories'])
                    : null,
            restrictedItems:
                (_tripData['restricted_items'] as List?)?.isEmpty == false
                    ? List<String>.from(_tripData['restricted_items'])
                    : null,
          );
          print('DEBUG: _tripService.createTrip completed successfully');

          // Upload images if any selected
          if (_selectedImages.isNotEmpty && createdTrip.id != null) {
            try {
              print(
                  'DEBUG: Uploading ${_selectedImages.length} images for trip ${createdTrip.id}');
              await _tripImageService.uploadTripImages(
                  createdTrip.id.toString(), _selectedImages);
              print('DEBUG: Images uploaded successfully');
            } catch (e) {
              print('Warning: Image upload failed: $e');
            }
          }
        } catch (e) {
          print('DEBUG: ERROR in createTrip: $e');
          print('DEBUG: Error type: ${e.runtimeType}');
          rethrow;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voyage créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );

          context.go('/home');
        }
      }
    } catch (e) {
      print('=== DEBUG: Final catch block - error: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Error stack trace: ${StackTrace.current}');

      // Extract user-friendly error message
      String errorMessage = 'Une erreur est survenue';
      if (e.toString().contains('TripException:')) {
        // Extract message after "TripException: "
        String fullError = e.toString();
        if (fullError.contains('TripException: ')) {
          errorMessage = fullError.split('TripException: ')[1];
          // Remove any "Validation failed: " prefix
          if (errorMessage.startsWith('Validation failed: ')) {
            errorMessage = errorMessage.substring('Validation failed: '.length);
          }
        }
      } else {
        errorMessage = e.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
