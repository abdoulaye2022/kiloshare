import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TripDetailsScreenSimple extends StatelessWidget {
  final String tripId;

  const TripDetailsScreenSimple({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Colors.blue,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Données statiques pour test
            Text(
              'Montréal → Paris',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            Text('Départ: Montréal, Canada'),
            Text('Arrivée: Paris, France'),
            Text('Poids: 15.0 kg'),
            Text('Prix: 25.0 CAD'),
            Text('Statut: active'),
            
            SizedBox(height: 32),
            
            Text('Connectez-vous pour plus d\'options:'),
            SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pop(),
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}