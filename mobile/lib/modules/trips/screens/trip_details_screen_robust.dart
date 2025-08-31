import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';
import '../../auth/services/auth_service.dart';

class TripDetailsScreenRobust extends StatefulWidget {
  final String tripId;

  const TripDetailsScreenRobust({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsScreenRobust> createState() => _TripDetailsScreenRobustState();
}

class _TripDetailsScreenRobustState extends State<TripDetailsScreenRobust> {
  Trip? _trip;
  bool _isLoading = true;
  String? _error;
  bool _isAuthenticated = false;
  late final TripService _tripService;
  bool _isLoadingInProgress = false;

  @override
  void initState() {
    super.initState();
    _tripService = TripService();
    _checkAuthAndLoadTrip();
  }
  
  Future<void> _checkAuthAndLoadTrip() async {
    // Check auth status without causing loops
    try {
      final token = await AuthService.instance.getStoredToken();
      final isAuth = token != null && !AuthService.instance.isTokenExpired(token);
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
    
    // Load trip
    await _loadTrip();
  }

  Future<void> _loadTrip() async {
    if (_isLoadingInProgress) {
      print('_loadTrip: Already loading, skipping duplicate call');
      return;
    }
    
    _isLoadingInProgress = true;
    print('_loadTrip: Starting to load trip ${widget.tripId}');
    
    try {
      final trip = await _tripService.getTripById(widget.tripId);
      print('_loadTrip: Trip loaded successfully');
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('_loadTrip: Error loading trip: $e');
      if (mounted) {
        setState(() {
          _trip = null;
          _isLoading = false;
          _error = e.toString();
        });
      }
    } finally {
      _isLoadingInProgress = false;
      print('_loadTrip: Loading completed');
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
      return const Center(child: CircularProgressIndicator());
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
                _loadTrip();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_trip == null) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info de base - avec gestion sécurisée des valeurs null
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_trip!.departureCity ?? 'N/A'} → ${_trip!.arrivalCity ?? 'N/A'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_trip!.departureCountry ?? 'N/A'} → ${_trip!.arrivalCountry ?? 'N/A'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Détails - avec gestion sécurisée
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
                  
                  _buildDetailRow(context, 'Poids disponible', 
                      '${_trip!.availableWeightKg.toStringAsFixed(1)} kg'),
                  _buildDetailRow(context, 'Prix par kg', 
                      '${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}'),
                  _buildDetailRow(context, 'Statut', _trip!.status.toString()),
                  
                  if (_trip!.flightNumber?.isNotEmpty ?? false)
                    _buildDetailRow(context, 'Vol', _trip!.flightNumber!),
                  
                  if (_trip!.description?.isNotEmpty ?? false) ...[
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

          // Action section - based on cached auth state
          _buildActionSection(context),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
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

  Widget _buildActionSection(BuildContext context) {
    if (_isAuthenticated) {
      // User is authenticated - show contact options
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
                'Contactez le transporteur pour réserver votre espace.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
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
              ),
            ],
          ),
        ),
      );
    } else {
      // User not authenticated - show login prompt
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
                'Connectez-vous pour contacter le transporteur et réserver votre espace.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
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
}