import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TripDetailsScreenUITest extends StatelessWidget {
  final String tripId;

  const TripDetailsScreenUITest({
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
      body: FutureBuilder<Map<String, String>>(
        // Simuler un appel API avec des données statiques
        future: _getStaticTripData(),
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
          
          final tripData = snapshot.data!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de base
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tripData['departure']} → ${tripData['arrival']}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tripData['departureCountry']} → ${tripData['arrivalCountry']}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Card de détails
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
                        
                        _buildDetailRow(context, 'Date de départ', tripData['departureDate']!),
                        _buildDetailRow(context, 'Date d\'arrivée', tripData['arrivalDate']!),
                        _buildDetailRow(context, 'Poids disponible', '${tripData['weight']} kg'),
                        _buildDetailRow(context, 'Prix par kg', '${tripData['price']} ${tripData['currency']}'),
                        _buildDetailRow(context, 'Statut', tripData['status']!),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Card d'invitation
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

  Future<Map<String, String>> _getStaticTripData() async {
    // Simuler un délai d'API
    await Future.delayed(const Duration(milliseconds: 500));
    
    return {
      'departure': 'Montréal',
      'arrival': 'Paris',
      'departureCountry': 'Canada',
      'arrivalCountry': 'France',
      'departureDate': '03/09/2025 19:09',
      'arrivalDate': '04/10/2025 19:09',
      'weight': '15.0',
      'price': '25.0',
      'currency': 'CAD',
      'status': 'active',
    };
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