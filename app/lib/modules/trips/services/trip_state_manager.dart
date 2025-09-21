import '../models/trip_model.dart';

class TripStateManager {
  static const Map<TripStatus, List<TripStatus>> _allowedTransitions = {
    TripStatus.draft: [TripStatus.pendingReview, TripStatus.active],
    TripStatus.pendingReview: [TripStatus.active, TripStatus.rejected],
    TripStatus.active: [TripStatus.paused, TripStatus.cancelled, TripStatus.booked, TripStatus.expired],
    TripStatus.rejected: [TripStatus.draft],
    TripStatus.paused: [TripStatus.active, TripStatus.cancelled],
    TripStatus.booked: [TripStatus.inProgress, TripStatus.cancelled],
    TripStatus.inProgress: [TripStatus.completed, TripStatus.cancelled],
    TripStatus.completed: [],
    TripStatus.cancelled: [],
    TripStatus.expired: [],
  };

  static const Map<TripStatus, List<TripAction>> _availableActions = {
    TripStatus.draft: [
      TripAction.publish,
      TripAction.edit,
      TripAction.delete,
      TripAction.duplicate,
    ],
    TripStatus.pendingReview: [
      TripAction.view,
      TripAction.share,
    ],
    TripStatus.active: [
      TripAction.pause,
      TripAction.edit,
      TripAction.cancel,
      TripAction.share,
      TripAction.viewAnalytics,
      TripAction.duplicate,
    ],
    TripStatus.rejected: [
      TripAction.edit,
      TripAction.republish,
      TripAction.delete,
      TripAction.duplicate,
    ],
    TripStatus.paused: [
      TripAction.resume,
      TripAction.cancel,
      TripAction.edit,
      TripAction.share,
      TripAction.viewAnalytics,
    ],
    TripStatus.booked: [
      TripAction.complete,
      TripAction.cancel,
      TripAction.viewAnalytics,
      TripAction.share,
    ],
    TripStatus.inProgress: [
      TripAction.complete,
      TripAction.cancel,
      TripAction.viewAnalytics,
    ],
    TripStatus.completed: [
      TripAction.view,
      TripAction.share,
      TripAction.viewAnalytics,
      TripAction.duplicate,
    ],
    TripStatus.cancelled: [
      TripAction.view,
      TripAction.duplicate,
    ],
    TripStatus.expired: [
      TripAction.view,
      TripAction.duplicate,
    ],
  };

  /// Check if a status transition is allowed
  static bool canTransitionTo(TripStatus from, TripStatus to) {
    return _allowedTransitions[from]?.contains(to) ?? false;
  }

  /// Get available actions for a trip status
  static List<TripAction> getAvailableActions(TripStatus status) {
    return _availableActions[status] ?? [];
  }

  /// Check if an action is available for a trip
  static bool canPerformAction(Trip trip, TripAction action) {
    final availableActions = getAvailableActions(trip.status);
    
    if (!availableActions.contains(action)) {
      return false;
    }

    // Additional business logic checks
    switch (action) {
      case TripAction.publish:
        return trip.canBePublished;
      
      case TripAction.edit:
        return trip.isEditable;
      
      case TripAction.pause:
        return trip.status == TripStatus.active && 
               trip.departureDate.isAfter(DateTime.now());
      
      case TripAction.resume:
        return trip.status == TripStatus.paused && 
               trip.departureDate.isAfter(DateTime.now());
      
      case TripAction.cancel:
        return [TripStatus.active, TripStatus.paused, TripStatus.booked, TripStatus.inProgress]
            .contains(trip.status) && 
               trip.departureDate.isAfter(DateTime.now().subtract(const Duration(hours: 24)));
      
      case TripAction.complete:
        return [TripStatus.booked, TripStatus.inProgress].contains(trip.status) && 
               trip.arrivalDate.isBefore(DateTime.now());
      
      case TripAction.republish:
        return trip.status == TripStatus.rejected && trip.canBePublished;
      
      default:
        return true;
    }
  }

  /// Get user-friendly action labels
  static String getActionLabel(TripAction action) {
    switch (action) {
      case TripAction.publish:
        return 'Publier';
      case TripAction.edit:
        return 'Modifier';
      case TripAction.delete:
        return 'Supprimer';
      case TripAction.pause:
        return 'Mettre en pause';
      case TripAction.resume:
        return 'Reprendre';
      case TripAction.cancel:
        return 'Annuler';
      case TripAction.complete:
        return 'Marquer comme terminé';
      case TripAction.share:
        return 'Partager';
      case TripAction.duplicate:
        return 'Dupliquer';
      case TripAction.view:
        return 'Voir détails';
      case TripAction.viewAnalytics:
        return 'Voir statistiques';
      case TripAction.addToFavorites:
        return 'Ajouter aux favoris';
      case TripAction.removeFromFavorites:
        return 'Retirer des favoris';
      case TripAction.report:
        return 'Signaler';
      case TripAction.republish:
        return 'Republier';
    }
  }

  /// Get action icons
  static String getActionIcon(TripAction action) {
    switch (action) {
      case TripAction.publish:
        return '🚀';
      case TripAction.edit:
        return '✏️';
      case TripAction.delete:
        return '🗑️';
      case TripAction.pause:
        return '⏸️';
      case TripAction.resume:
        return '▶️';
      case TripAction.cancel:
        return '❌';
      case TripAction.complete:
        return '✅';
      case TripAction.share:
        return '📤';
      case TripAction.duplicate:
        return '📋';
      case TripAction.view:
        return '👁️';
      case TripAction.viewAnalytics:
        return '📊';
      case TripAction.addToFavorites:
        return '⭐';
      case TripAction.removeFromFavorites:
        return '⭐';
      case TripAction.report:
        return '🚨';
      case TripAction.republish:
        return '🔄';
    }
  }

  /// Get status color
  static String getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.draft:
        return '#6B7280'; // Gray
      case TripStatus.pendingReview:
        return '#F59E0B'; // Amber
      case TripStatus.active:
        return '#10B981'; // Green
      case TripStatus.rejected:
        return '#EF4444'; // Red
      case TripStatus.paused:
        return '#F59E0B'; // Amber
      case TripStatus.booked:
        return '#3B82F6'; // Blue
      case TripStatus.inProgress:
        return '#8B5CF6'; // Purple
      case TripStatus.completed:
        return '#059669'; // Emerald
      case TripStatus.cancelled:
        return '#6B7280'; // Gray
      case TripStatus.expired:
        return '#9CA3AF'; // Gray
      case TripStatus.pendingApproval:
        return '#F59E0B'; // Amber
    }
  }

  /// Get next possible statuses for a trip
  static List<TripStatus> getNextPossibleStatuses(TripStatus currentStatus) {
    return _allowedTransitions[currentStatus] ?? [];
  }

  /// Check if trip is in a final state (no more actions possible)
  static bool isFinalState(TripStatus status) {
    return [TripStatus.completed, TripStatus.cancelled, TripStatus.expired]
        .contains(status);
  }

  /// Check if trip requires user attention
  static bool requiresAttention(Trip trip) {
    return [TripStatus.rejected, TripStatus.pendingReview].contains(trip.status) ||
           (trip.status == TripStatus.active && trip.remainingDays <= 1);
  }

  /// Get priority level for trip
  static TripPriority getPriority(Trip trip) {
    if (trip.isUrgent) return TripPriority.high;
    if (trip.isFeatured) return TripPriority.high;
    if (requiresAttention(trip)) return TripPriority.medium;
    if (trip.remainingDays <= 7) return TripPriority.medium;
    return TripPriority.low;
  }
}

enum TripAction {
  publish,
  edit,
  delete,
  pause,
  resume,
  cancel,
  complete,
  share,
  duplicate,
  view,
  viewAnalytics,
  addToFavorites,
  removeFromFavorites,
  report,
  republish,
}

enum TripPriority {
  low,
  medium,
  high,
}