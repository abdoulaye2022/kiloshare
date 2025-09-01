import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';

class TripDetailsScreenMinimal extends StatelessWidget {
  final String tripId;

  const TripDetailsScreenMinimal({
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Erreur de chargement'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return const Center(child: Text('Aucune donnée'));
          }
          
          final trip = snapshot.data!;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre simple
                Text(
                  '${trip.departureCity} → ${trip.arrivalCity}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Informations de base uniquement
                Text('Départ: ${trip.departureCity}, ${trip.departureCountry}'),
                Text('Arrivée: ${trip.arrivalCity}, ${trip.arrivalCountry}'),
                Text('Poids: ${trip.availableWeightKg} kg'),
                Text('Prix: ${trip.pricePerKg} ${trip.currency}'),
                Text('Statut: ${trip.status}'),
                
                const SizedBox(height: 32),
                
                // Boutons de connexion simples
                const Text('Connectez-vous pour plus d\'options:'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Se connecter'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('S\'inscrire'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}