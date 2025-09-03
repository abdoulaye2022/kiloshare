import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../models/transport_models.dart';
import 'create_trip_screen.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';

class TripTypeSelectionScreen extends StatelessWidget {
  const TripTypeSelectionScreen({super.key});

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
            return _buildTripTypeSelection(context);
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

  Widget _buildTripTypeSelection(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir le type de transport'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.flight_takeoff,
                      size: 48,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quel type de transport utilisez-vous ?',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sélectionnez votre moyen de transport pour créer votre annonce de voyage',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Transport options
              ...TransportType.values.map(
                (transportType) => _buildTransportCard(context, transportType),
              ),
              
              const SizedBox(height: 32),
              
              // Information section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'À savoir',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Chaque type de transport a ses propres limites de poids\n'
                      '• Les tarifs sont calculés automatiquement selon la distance\n'
                      '• Vous pourrez personnaliser votre prix après sélection\n'
                      '• Certains transports requièrent des informations spécifiques',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportCard(BuildContext context, TransportType transportType) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToCreateTrip(context, transportType),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Transport icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _getTransportColor(transportType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getTransportIcon(transportType),
                    size: 32,
                    color: _getTransportColor(transportType),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Transport info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transportType.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transportType.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.scale,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_getWeightLimit(transportType)} kg max',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTransportIcon(TransportType transportType) {
    switch (transportType) {
      case TransportType.flight:
        return Icons.flight;
      case TransportType.car:
        return Icons.directions_car;
    }
  }

  Color _getTransportColor(TransportType transportType) {
    switch (transportType) {
      case TransportType.flight:
        return Colors.blue[600]!;
      case TransportType.car:
        return Colors.green[600]!;
    }
  }

  double _getWeightLimit(TransportType transportType) {
    switch (transportType) {
      case TransportType.flight:
        return 23.0;
      case TransportType.car:
        return 100.0;
    }
  }

  void _navigateToCreateTrip(BuildContext context, TransportType transportType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(
          initialTransportType: transportType,
        ),
      ),
    );
  }
}