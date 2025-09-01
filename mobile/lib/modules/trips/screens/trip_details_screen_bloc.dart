import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../bloc/trip_bloc.dart';
import '../models/trip_model.dart';
import '../widgets/trip_status_widget.dart';

class TripDetailsScreenBloc extends StatelessWidget {
  final String tripId;

  const TripDetailsScreenBloc({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TripBloc()..add(LoadTripById(tripId)),
      child: _TripDetailsView(tripId: tripId),
    );
  }
}

class _TripDetailsView extends StatelessWidget {
  final String tripId;

  const _TripDetailsView({required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Pas d'actions pour éviter les problèmes d'authentification
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
          } else if (state is TripDeleted) {
            // Navigate back after successful deletion
            context.pop();
          }
        },
        builder: (context, state) {
          if (state is TripLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (state is TripError) {
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
                      state.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<TripBloc>().add(LoadTripById(tripId));
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          
          if (state is TripDetailsLoaded) {
            return _buildTripDetails(context, state.trip);
          }
          
          // Handle other states that might have trip data
          if (state is TripActionSuccess && state.updatedTrip != null) {
            // Reload trip details to get fresh data
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<TripBloc>().add(LoadTripById(tripId));
            });
            return const Center(child: CircularProgressIndicator());
          }
          
          return const Center(
            child: Text('Aucune donnée disponible'),
          );
        },
      ),
    );
  }

  Widget _buildTripDetails(BuildContext context, Trip trip) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<TripBloc>().add(LoadTripById(tripId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip basic info - sans actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${trip.departureCity} → ${trip.arrivalCity}',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${trip.departureCountry} → ${trip.arrivalCountry}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Pas de bouton favoris pour éviter les problèmes d'auth
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Trip status widget
            TripStatusWidget(trip: trip),

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
                    
                    _buildDetailRow(context, 'Date de départ', 
                        DateFormat('dd/MM/yyyy HH:mm').format(trip.departureDate.toLocal())),
                    _buildDetailRow(context, 'Date d\'arrivée', 
                        DateFormat('dd/MM/yyyy HH:mm').format(trip.arrivalDate.toLocal())),
                    _buildDetailRow(context, 'Poids disponible', 
                        '${trip.availableWeightKg.toStringAsFixed(1)} kg'),
                    _buildDetailRow(context, 'Prix par kg', 
                        '${trip.pricePerKg.toStringAsFixed(2)} ${trip.currency}'),
                    
                    if (trip.flightNumber?.isNotEmpty ?? false)
                      _buildDetailRow(context, 'Numéro de vol', trip.flightNumber!),
                    
                    if (trip.airline?.isNotEmpty ?? false)
                      _buildDetailRow(context, 'Compagnie aérienne', trip.airline!),
                    
                    if (trip.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trip.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Message d'information pour utilisateurs non connectés
            Card(
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
                      'Connectez-vous pour contacter le transporteur et accéder à toutes les fonctionnalités.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('/login');
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Se connecter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/register');
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('S\'inscrire'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
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
}