import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/trip_bloc.dart';
import '../models/trip_model.dart';
import '../services/trip_state_manager.dart' as state_manager;

class TripActionsWidgetBloc extends StatelessWidget {
  final Trip trip;

  const TripActionsWidgetBloc({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final availableActions = state_manager.TripStateManager.getAvailableActions(trip.status);

    if (availableActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableActions.map((action) {
                return _buildActionButton(context, action);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, state_manager.TripAction action) {
    final bloc = context.read<TripBloc>();
    
    switch (action) {
      case state_manager.TripAction.publish:
        return ElevatedButton.icon(
          onPressed: () => bloc.add(PublishTrip(trip.id)),
          icon: const Icon(Icons.publish),
          label: const Text('Publier'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        );

      case state_manager.TripAction.edit:
        return OutlinedButton.icon(
          onPressed: () => _showEditDialog(context),
          icon: const Icon(Icons.edit),
          label: const Text('Modifier'),
        );

      case state_manager.TripAction.pause:
        return OutlinedButton.icon(
          onPressed: () => _showPauseDialog(context, bloc),
          icon: const Icon(Icons.pause),
          label: const Text('Mettre en pause'),
        );

      case state_manager.TripAction.resume:
        return ElevatedButton.icon(
          onPressed: () => bloc.add(ResumeTrip(trip.id)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Reprendre'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        );

      case state_manager.TripAction.cancel:
        return OutlinedButton.icon(
          onPressed: () => _showCancelDialog(context, bloc),
          icon: const Icon(Icons.cancel),
          label: const Text('Annuler'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
          ),
        );

      case state_manager.TripAction.complete:
        return ElevatedButton.icon(
          onPressed: () => _showCompleteDialog(context, bloc),
          icon: const Icon(Icons.check_circle),
          label: const Text('Terminer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        );

      case state_manager.TripAction.duplicate:
        return OutlinedButton.icon(
          onPressed: () => bloc.add(DuplicateTrip(trip.id)),
          icon: const Icon(Icons.copy),
          label: const Text('Dupliquer'),
        );

      case state_manager.TripAction.delete:
        return OutlinedButton.icon(
          onPressed: () => _showDeleteDialog(context, bloc),
          icon: const Icon(Icons.delete),
          label: const Text('Supprimer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        );

      case state_manager.TripAction.share:
        return OutlinedButton.icon(
          onPressed: () => bloc.add(ShareTrip(trip.id)),
          icon: const Icon(Icons.share),
          label: const Text('Partager'),
        );

      case state_manager.TripAction.viewAnalytics:
        return OutlinedButton.icon(
          onPressed: () => _showAnalyticsDialog(context),
          icon: const Icon(Icons.analytics),
          label: const Text('Analytics'),
        );

      case state_manager.TripAction.report:
        return OutlinedButton.icon(
          onPressed: () => _showReportDialog(context, bloc),
          icon: const Icon(Icons.report),
          label: const Text('Signaler'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        );

      case state_manager.TripAction.addToFavorites:
        return OutlinedButton.icon(
          onPressed: () => bloc.add(AddToFavorites(trip.id)),
          icon: const Icon(Icons.favorite_border),
          label: const Text('Favori'),
        );

      case state_manager.TripAction.removeFromFavorites:
        return OutlinedButton.icon(
          onPressed: () => bloc.add(RemoveFromFavorites(trip.id)),
          icon: const Icon(Icons.favorite),
          label: const Text('Retirer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        );

      case state_manager.TripAction.view:
        return OutlinedButton.icon(
          onPressed: () {
            // This action typically navigates to details, but we're already here
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vous êtes déjà sur la page de détails')),
            );
          },
          icon: const Icon(Icons.visibility),
          label: const Text('Voir'),
        );

      case state_manager.TripAction.republish:
        return ElevatedButton.icon(
          onPressed: () => bloc.add(PublishTrip(trip.id)),
          icon: const Icon(Icons.refresh),
          label: const Text('Republier'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        );
    }
  }

  void _showEditDialog(BuildContext context) {
    // Navigate to edit trip screen
    context.push('/trips/edit/${trip.id}');
  }

  void _showPauseDialog(BuildContext context, TripBloc bloc) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mettre en pause'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pourquoi souhaitez-vous mettre ce voyage en pause ?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              bloc.add(PauseTrip(trip.id, reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim()));
            },
            child: const Text('Mettre en pause'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, TripBloc bloc) {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le voyage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Êtes-vous sûr de vouloir annuler ce voyage ?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(
                labelText: 'Détails (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              bloc.add(CancelTrip(
                trip.id,
                reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                details: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
              ));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, TripBloc bloc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer le voyage'),
        content: const Text('Confirmez-vous que ce voyage est terminé ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              bloc.add(CompleteTrip(trip.id));
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, TripBloc bloc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le voyage'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce voyage ? Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              bloc.add(DeleteTrip(trip.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, TripBloc bloc) {
    String reportType = 'spam';
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Signaler ce voyage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reportType,
                decoration: const InputDecoration(
                  labelText: 'Type de signalement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(value: 'fraud', child: Text('Fraude')),
                  DropdownMenuItem(value: 'inappropriate', child: Text('Contenu inapproprié')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      reportType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                bloc.add(ReportTrip(
                  trip.id,
                  reportType,
                  description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                ));
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics'),
        content: const Text('Les analytics détaillées seront bientôt disponibles.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}