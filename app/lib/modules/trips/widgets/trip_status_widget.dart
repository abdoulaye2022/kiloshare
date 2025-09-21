import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_state_manager.dart';

class TripStatusWidget extends StatelessWidget {
  final Trip trip;
  final bool showDetails;
  final bool showMetrics;

  const TripStatusWidget({
    super.key,
    required this.trip,
    this.showDetails = true,
    this.showMetrics = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(context),
            if (showDetails) ...[
              const SizedBox(height: 12),
              _buildStatusDetails(context),
            ],
            if (showMetrics) ...[
              const SizedBox(height: 12),
              _buildMetrics(context),
            ],
            if (_shouldShowWarning()) ...[
              const SizedBox(height: 12),
              _buildWarning(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    return Row(
      children: [
        _buildStatusBadge(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.status.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_getPriorityText() != null)
                Text(
                  _getPriorityText()!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getPriorityColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (trip.isUrgent)
          const Icon(
            Icons.priority_high,
            color: Colors.red,
            size: 20,
          ),
        if (trip.isFeatured)
          const Icon(
            Icons.star,
            color: Colors.amber,
            size: 20,
          ),
        if (trip.isVerified)
          const Icon(
            Icons.verified,
            color: Colors.blue,
            size: 20,
          ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final color = Color(int.parse(TripStateManager.getStatusColor(trip.status).substring(1), radix: 16) + 0xFF000000);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            trip.status.displayName.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetails(BuildContext context) {
    final details = <Widget>[];

    // Dates importantes selon le statut
    switch (trip.status) {
      case TripStatus.draft:
        details.add(_buildDetailRow(
          context,
          'Créé le',
          _formatDate(trip.createdAt),
          Icons.calendar_today,
        ));
        break;
      
      case TripStatus.pendingReview:
        if (trip.publishedAt != null) {
          details.add(_buildDetailRow(
            context,
            'Soumis le',
            _formatDate(trip.publishedAt!),
            Icons.upload,
          ));
        }
        break;
      
      case TripStatus.active:
        if (trip.publishedAt != null) {
          details.add(_buildDetailRow(
            context,
            'Publié le',
            _formatDate(trip.publishedAt!),
            Icons.public,
          ));
        }
        details.add(_buildDetailRow(
          context,
          'Départ dans',
          '${trip.remainingDays} jour(s)',
          Icons.schedule,
        ));
        break;
      
      case TripStatus.paused:
        if (trip.pausedAt != null) {
          details.add(_buildDetailRow(
            context,
            'Mis en pause le',
            _formatDate(trip.pausedAt!),
            Icons.pause,
          ));
        }
        if (trip.pauseReason != null) {
          details.add(_buildDetailRow(
            context,
            'Raison',
            trip.pauseReason!,
            Icons.info,
          ));
        }
        break;
      
      case TripStatus.cancelled:
        if (trip.cancelledAt != null) {
          details.add(_buildDetailRow(
            context,
            'Annulé le',
            _formatDate(trip.cancelledAt!),
            Icons.cancel,
          ));
        }
        if (trip.cancellationReason != null) {
          details.add(_buildDetailRow(
            context,
            'Raison',
            trip.cancellationReason!,
            Icons.info,
          ));
        }
        break;
      
      case TripStatus.completed:
        if (trip.completedAt != null) {
          details.add(_buildDetailRow(
            context,
            'Terminé le',
            _formatDate(trip.completedAt!),
            Icons.check_circle,
          ));
        }
        break;
      
      case TripStatus.rejected:
        if (trip.rejectedAt != null) {
          details.add(_buildDetailRow(
            context,
            'Rejeté le',
            _formatDate(trip.rejectedAt!),
            Icons.block,
          ));
        }
        if (trip.rejectionReason != null) {
          details.add(_buildDetailRow(
            context,
            'Raison du rejet',
            trip.rejectionReason!,
            Icons.warning,
          ));
        }
        break;
      
      case TripStatus.expired:
        if (trip.expiredAt != null) {
          details.add(_buildDetailRow(
            context,
            'Expiré le',
            _formatDate(trip.expiredAt!),
            Icons.access_time,
          ));
        }
        break;
      
      default:
        break;
    }

    return Column(
      children: details,
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métriques',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                'Vues',
                trip.viewCount.toString(),
                Icons.visibility,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                context,
                'Favoris',
                trip.favoriteCount.toString(),
                Icons.favorite,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                context,
                'Partages',
                trip.shareCount.toString(),
                Icons.share,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getWarningMessage(),
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowWarning() {
    return TripStateManager.requiresAttention(trip) ||
           (trip.status == TripStatus.active && trip.remainingDays <= 1) ||
           trip.reportCount > 0;
  }

  String _getWarningMessage() {
    if (trip.status == TripStatus.rejected) {
      return 'Ce voyage a été rejeté. Modifiez-le pour le republier.';
    } else if (trip.status == TripStatus.pendingReview) {
      return 'Ce voyage est en cours de révision par notre équipe.';
    } else if (trip.status == TripStatus.active && trip.remainingDays <= 1) {
      return 'Départ imminent ! Préparez-vous pour le voyage.';
    } else if (trip.reportCount > 0) {
      return 'Ce voyage a été signalé ${trip.reportCount} fois.';
    }
    return 'Ce voyage nécessite votre attention.';
  }

  String? _getPriorityText() {
    final priority = TripStateManager.getPriority(trip);
    switch (priority) {
      case TripPriority.high:
        return 'Priorité élevée';
      case TripPriority.medium:
        return 'Priorité moyenne';
      case TripPriority.low:
        return null;
    }
  }

  Color? _getPriorityColor() {
    final priority = TripStateManager.getPriority(trip);
    switch (priority) {
      case TripPriority.high:
        return Colors.red[600];
      case TripPriority.medium:
        return Colors.orange[600];
      case TripPriority.low:
        return Colors.grey[600];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}