import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../../auth/services/auth_service.dart';

class TripDetailsSimple extends StatefulWidget {
  final String tripId;

  const TripDetailsSimple({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsSimple> createState() => _TripDetailsSimpleState();
}

class _TripDetailsSimpleState extends State<TripDetailsSimple> {
  Trip? _trip;
  bool _isLoading = true;
  String? _error;
  bool _isAuthenticated = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    if (_hasInitialized) {
      print('TripDetailsSimple: Already initialized, skipping');
      return;
    }
    
    print('TripDetailsSimple: Starting initialization for trip ${widget.tripId}');
    _hasInitialized = true;
    
    // Check auth status once
    try {
      final token = await AuthService.instance.getStoredToken();
      final isAuth = token != null && !AuthService.instance.isTokenExpired(token);
      print('TripDetailsSimple: Auth status: $isAuth');
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
        });
      }
    } catch (e) {
      print('TripDetailsSimple: Auth check failed: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
    
    // Load trip data
    await _loadTripData();
  }

  Future<void> _loadTripData() async {
    print('TripDetailsSimple: Loading trip data for ID: ${widget.tripId}');
    
    try {
      final tripService = TripService();
      final trip = await tripService.getTripById(widget.tripId);
      
      print('TripDetailsSimple: Trip loaded successfully');
      
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('TripDetailsSimple: Error loading trip: $e');
      
      if (mounted) {
        setState(() {
          _trip = null;
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des détails...'),
          ],
        ),
      );
    }

    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                  _hasInitialized = false;
                });
                _initializeScreen();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_trip == null) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_trip!.departureCity} → ${_trip!.arrivalCity}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_trip!.departureCountry} → ${_trip!.arrivalCountry}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Trip details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détails du voyage',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDetailRow('Poids disponible', '${_trip!.availableWeightKg.toStringAsFixed(1)} kg'),
                  _buildDetailRow('Prix par kg', '${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}'),
                  _buildDetailRow('Statut', _trip!.status.toString()),
                  
                  if (_trip!.flightNumber?.isNotEmpty == true)
                    _buildDetailRow('Vol', _trip!.flightNumber!),
                    
                  if (_trip!.airline?.isNotEmpty == true)
                    _buildDetailRow('Compagnie', _trip!.airline!),
                  
                  if (_trip!.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _trip!.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          _buildActionCard(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intéressé par ce voyage?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAuthenticated
                  ? 'Contactez le transporteur pour réserver votre espace.'
                  : 'Connectez-vous pour contacter le transporteur.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _isAuthenticated
                ? Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fonctionnalité de contact bientôt disponible'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Contacter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voyage ajouté aux favoris'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bookmark_border),
                        label: const Text('Sauvegarder'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.push('/login'),
                        icon: const Icon(Icons.login),
                        label: const Text('Se connecter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/register'),
                        icon: const Icon(Icons.person_add),
                        label: const Text('S\'inscrire'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}