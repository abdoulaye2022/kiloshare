import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../widgets/trip_status_widget.dart';

class TripDetailsScreenStatic extends StatelessWidget {
  final String tripId;

  const TripDetailsScreenStatic({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<Trip>(
        future: TripService().getTripById(tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
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
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Rebuild the widget to retry
                      context.pop();
                      context.push('/trips/$tripId');
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return const Center(
              child: Text('Aucune donnée disponible'),
            );
          }
          
          final trip = snapshot.data!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip basic info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                ),

                const SizedBox(height: 16),

                // Trip status
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

                // Login prompt
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
          );
        },
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