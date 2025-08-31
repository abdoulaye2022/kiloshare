import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../../auth/services/auth_service.dart';

class TripDetailsStatic extends StatefulWidget {
  final String tripId;

  const TripDetailsStatic({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsStatic> createState() => _TripDetailsStaticState();
}

class _TripDetailsStaticState extends State<TripDetailsStatic> with AutomaticKeepAliveClientMixin {
  Trip? _trip;
  bool _isLoading = true;
  String? _error;
  bool _isAuthenticated = false;
  
  // Prevent widget from being disposed and rebuilt
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    print('TripDetailsStatic: Loading data for trip ${widget.tripId}');
    
    // Load auth status and trip in parallel
    final futures = await Future.wait([
      _getAuthStatus(),
      _getTripData(),
    ]);
    
    final isAuth = futures[0] as bool;
    final tripData = futures[1] as Map<String, dynamic>;
    
    if (!mounted) return;
    
    setState(() {
      _isAuthenticated = isAuth;
      _trip = tripData['trip'] as Trip?;
      _error = tripData['error'] as String?;
      _isLoading = false;
    });
    
    print('TripDetailsStatic: Data loaded successfully');
  }

  Future<bool> _getAuthStatus() async {
    try {
      final token = await AuthService.instance.getStoredToken();
      return token != null && !AuthService.instance.isTokenExpired(token);
    } catch (e) {
      print('TripDetailsStatic: Auth check error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _getTripData() async {
    try {
      final tripService = TripService();
      final trip = await tripService.getTripById(widget.tripId);
      return {'trip': trip, 'error': null};
    } catch (e) {
      print('TripDetailsStatic: Trip load error: $e');
      return {'trip': null, 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
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
                });
                _loadData();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_trip == null) {
      return const Center(
        child: Text('Voyage non trouvé'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip header card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_trip!.departureCity} → ${_trip!.arrivalCity}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_trip!.departureCountry} → ${_trip!.arrivalCountry}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Trip details card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations du voyage',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(
                    Icons.luggage,
                    'Poids disponible',
                    '${_trip!.availableWeightKg.toStringAsFixed(1)} kg',
                  ),
                  _buildInfoRow(
                    Icons.attach_money,
                    'Prix par kg',
                    '${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}',
                  ),
                  _buildInfoRow(
                    Icons.info_outline,
                    'Statut',
                    _getStatusText(_trip!.status),
                  ),
                  
                  if (_trip!.flightNumber?.isNotEmpty == true)
                    _buildInfoRow(
                      Icons.airplane_ticket,
                      'Numéro de vol',
                      _trip!.flightNumber!,
                    ),
                    
                  if (_trip!.airline?.isNotEmpty == true)
                    _buildInfoRow(
                      Icons.business,
                      'Compagnie',
                      _trip!.airline!,
                    ),
                ],
              ),
            ),
          ),

          if (_trip!.description?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _trip!.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Intéressé par ce voyage ?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isAuthenticated
                        ? 'Contactez le transporteur pour réserver votre espace.'
                        : 'Connectez-vous pour contacter le transporteur.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isAuthenticated) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fonctionnalité de contact bientôt disponible'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Contacter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voyage ajouté aux favoris'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Sauvegarder'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Se connecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/register'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('S\'inscrire'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  String _getStatusText(dynamic status) {
    switch (status.toString()) {
      case 'active':
        return 'Actif';
      case 'draft':
        return 'Brouillon';
      case 'published':
        return 'Publié';
      case 'paused':
        return 'En pause';
      case 'cancelled':
        return 'Annulé';
      case 'completed':
        return 'Terminé';
      default:
        return status.toString();
    }
  }
}