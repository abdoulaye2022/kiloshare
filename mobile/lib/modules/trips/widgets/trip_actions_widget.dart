import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../services/trip_state_manager.dart';

class TripActionsWidget extends StatefulWidget {
  final Trip trip;
  final Function(Trip)? onTripUpdated;
  final Function()? onTripDeleted;
  
  const TripActionsWidget({
    Key? key,
    required this.trip,
    this.onTripUpdated,
    this.onTripDeleted,
  }) : super(key: key);

  @override
  State<TripActionsWidget> createState() => _TripActionsWidgetState();
}

class _TripActionsWidgetState extends State<TripActionsWidget> {
  final TripService _tripService = TripService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final availableActions = TripStateManager.getAvailableActions(widget.trip.status)
        .where((action) => TripStateManager.canPerformAction(widget.trip, action))
        .toList();

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
              'Actions disponibles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableActions.map((action) => _buildActionButton(action)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(TripAction action) {
    final isDestructive = [TripAction.delete, TripAction.cancel].contains(action);
    final isPrimary = [TripAction.publish, TripAction.republish, TripAction.resume].contains(action);
    
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _handleAction(action),
      icon: Text(TripStateManager.getActionIcon(action)),
      label: Text(TripStateManager.getActionLabel(action)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive 
            ? Colors.red[50]
            : isPrimary
                ? Theme.of(context).primaryColor
                : Colors.grey[100],
        foregroundColor: isDestructive
            ? Colors.red[700]
            : isPrimary
                ? Colors.white
                : Colors.grey[700],
        elevation: 1,
      ),
    );
  }

  Future<void> _handleAction(TripAction action) async {
    setState(() => _isLoading = true);

    try {
      switch (action) {
        case TripAction.publish:
          await _publishTrip();
          break;
        case TripAction.republish:
          await _publishTrip();
          break;
        case TripAction.pause:
          await _pauseTrip();
          break;
        case TripAction.resume:
          await _resumeTrip();
          break;
        case TripAction.cancel:
          await _cancelTrip();
          break;
        case TripAction.complete:
          await _completeTrip();
          break;
        case TripAction.share:
          await _shareTrip();
          break;
        case TripAction.duplicate:
          await _duplicateTrip();
          break;
        case TripAction.delete:
          await _deleteTrip();
          break;
        case TripAction.edit:
          await _editTrip();
          break;
        case TripAction.view:
          await _viewTrip();
          break;
        case TripAction.viewAnalytics:
          await _viewAnalytics();
          break;
        case TripAction.addToFavorites:
          await _addToFavorites();
          break;
        case TripAction.removeFromFavorites:
          await _removeFromFavorites();
          break;
        case TripAction.report:
          await _reportTrip();
          break;
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _publishTrip() async {
    final updatedTrip = await _tripService.publishTrip(widget.trip.id);
    widget.onTripUpdated?.call(updatedTrip);
    _showSuccessSnackBar('Voyage publié avec succès');
  }

  Future<void> _pauseTrip() async {
    final reason = await _showReasonDialog('Raison de la pause (optionnel)');
    final updatedTrip = await _tripService.pauseTrip(widget.trip.id, reason: reason);
    widget.onTripUpdated?.call(updatedTrip);
    _showSuccessSnackBar('Voyage mis en pause');
  }

  Future<void> _resumeTrip() async {
    final updatedTrip = await _tripService.resumeTrip(widget.trip.id);
    widget.onTripUpdated?.call(updatedTrip);
    _showSuccessSnackBar('Voyage repris');
  }

  Future<void> _cancelTrip() async {
    final confirmed = await _showConfirmDialog(
      'Annuler le voyage',
      'Êtes-vous sûr de vouloir annuler ce voyage ?',
    );
    
    if (!confirmed) return;

    final reason = await _showReasonDialog('Raison de l\'annulation');
    final updatedTrip = await _tripService.cancelTrip(widget.trip.id, reason: reason);
    widget.onTripUpdated?.call(updatedTrip);
    _showSuccessSnackBar('Voyage annulé');
  }

  Future<void> _completeTrip() async {
    final confirmed = await _showConfirmDialog(
      'Marquer comme terminé',
      'Confirmer que ce voyage est terminé ?',
    );
    
    if (!confirmed) return;

    final updatedTrip = await _tripService.completeTrip(widget.trip.id);
    widget.onTripUpdated?.call(updatedTrip);
    _showSuccessSnackBar('Voyage marqué comme terminé');
  }

  Future<void> _shareTrip() async {
    final shareUrl = await _tripService.shareTrip(widget.trip.id);
    // TODO: Implement actual sharing (share_plus package)
    _showSuccessSnackBar('Lien de partage généré');
  }

  Future<void> _duplicateTrip() async {
    final duplicatedTrip = await _tripService.duplicateTrip(widget.trip.id);
    // TODO: Navigate to edit screen with duplicated trip
    _showSuccessSnackBar('Voyage dupliqué');
  }

  Future<void> _deleteTrip() async {
    final confirmed = await _showConfirmDialog(
      'Supprimer le voyage',
      'Cette action est irréversible. Continuer ?',
    );
    
    if (!confirmed) return;

    await _tripService.deleteTrip(widget.trip.id);
    widget.onTripDeleted?.call();
    _showSuccessSnackBar('Voyage supprimé');
  }

  Future<void> _editTrip() async {
    // TODO: Navigate to edit screen
    _showInfoSnackBar('Redirection vers l\'édition...');
  }

  Future<void> _viewTrip() async {
    // TODO: Navigate to trip details
    _showInfoSnackBar('Affichage des détails...');
  }

  Future<void> _viewAnalytics() async {
    // TODO: Navigate to analytics screen
    _showInfoSnackBar('Affichage des statistiques...');
  }

  Future<void> _addToFavorites() async {
    await _tripService.addToFavorites(widget.trip.id);
    _showSuccessSnackBar('Ajouté aux favoris');
  }

  Future<void> _removeFromFavorites() async {
    await _tripService.removeFromFavorites(widget.trip.id);
    _showSuccessSnackBar('Retiré des favoris');
  }

  Future<void> _reportTrip() async {
    final reportType = await _showReportDialog();
    if (reportType == null) return;

    await _tripService.reportTrip(widget.trip.id, reportType: reportType);
    _showSuccessSnackBar('Signalement envoyé');
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _showReasonDialog(String title) async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Saisir la raison...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return result?.isNotEmpty == true ? result : null;
  }

  Future<String?> _showReportDialog() async {
    String? selectedType;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Signaler ce voyage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              'spam',
              'fraud', 
              'inappropriate',
              'misleading',
              'prohibited_items',
              'suspicious_price',
              'other'
            ].map((type) => RadioListTile<String>(
              title: Text(_getReportTypeLabel(type)),
              value: type,
              groupValue: selectedType,
              onChanged: (value) => setState(() => selectedType = value),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedType != null
                  ? () => Navigator.of(context).pop(selectedType)
                  : null,
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  String _getReportTypeLabel(String type) {
    switch (type) {
      case 'spam':
        return 'Spam';
      case 'fraud':
        return 'Fraude';
      case 'inappropriate':
        return 'Contenu inapproprié';
      case 'misleading':
        return 'Information trompeuse';
      case 'prohibited_items':
        return 'Articles interdits';
      case 'suspicious_price':
        return 'Prix suspect';
      case 'other':
        return 'Autre';
      default:
        return type;
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
}