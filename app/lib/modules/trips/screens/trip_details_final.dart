import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../services/favorites_service.dart';
import '../../../widgets/ellipsis_button.dart';
import '../../auth/services/auth_service.dart';
import '../../booking/screens/create_booking_screen.dart';
import '../../booking/models/booking_model.dart';
import '../../delivery/screens/transporter_delivery_code_screen.dart';

class TripDetailsFinal extends StatefulWidget {
  final String tripId;

  const TripDetailsFinal({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsFinal> createState() => _TripDetailsFinalState();
}

class _TripDetailsFinalState extends State<TripDetailsFinal> {
  Trip? _trip;
  bool _isLoading = true;
  String? _error;
  bool _isAuthenticated = false;
  bool _isOwner = false;
  bool _hasLoaded = false;
  bool _isFavorite = false;
  bool _isStartingJourney = false;

  @override
  void initState() {
    super.initState();
    _loadDataOnce();
  }

  Future<void> _loadDataOnce() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    
    // Debug messages removed for production
    
    try {
      // Check auth status
      final token = await AuthService.instance.getStoredToken();
      final isAuth = token != null && !AuthService.instance.isTokenExpired(token);
      // Auth status checked
      
      String? userId;
      if (isAuth) {
        try {
          final user = await AuthService.instance.getCurrentUser();
          userId = user?.id.toString();
          // User ID obtained
        } catch (e) {
          // Error getting current user
        }
      } else {
        // Proceeding with public access
      }

      // Load trip data
      final tripService = TripService();
      // Loading trip data
      
      final trip = await tripService.getTripById(widget.tripId);
      
      // Trip loaded successfully
      
      // Check favorite status if authenticated and not owner
      bool isFavorite = false;
      if (isAuth && userId != null && trip.userId != userId) {
        try {
          // Checking favorite status
          isFavorite = await FavoritesService.instance.isFavorite(widget.tripId);
          // Favorite status checked
        } catch (e) {
          // Error checking favorite status
        }
      } else {
        // Skipping favorite check
      }
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _trip = trip;
          _isOwner = trip.isOwner ?? (trip.userId == userId);
          _isFavorite = isFavorite;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      // Error loading trip data
      
      String errorMessage;
      if (e.toString().contains('Trip not found')) {
        errorMessage = 'Cette annonce n\'est pas disponible.\n\nRaisons possibles :\n• Annonce en brouillon (visible seulement par le propriétaire)\n• Annonce supprimée ou expirée\n• Problème d\'authentification\n\nID demandé: ${widget.tripId}';
      } else {
        errorMessage = e.toString();
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = errorMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement...'),
          ],
        ),
      );
    }

    if (_error != null) {
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
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                  _hasLoaded = false;
                });
                _loadDataOnce();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_trip == null) {
      return const Center(child: Text('Voyage non trouvé'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          _buildStatusBanner(),
          const SizedBox(height: 16),
          
          // Trip header
          _buildTripHeader(),
          const SizedBox(height: 16),

          // Trip details
          _buildTripDetails(),
          
          if (_trip!.description?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildDescription(),
          ],
          
          
          // Special notes section
          if (_trip!.specialNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildSpecialNotesSection(),
          ],

          // Images section
          if (_trip!.hasImages) ...[
            const SizedBox(height: 16),
            _buildImagesSection(),
          ],

          const SizedBox(height: 16),
          
          // Actions
          _buildActions(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = _trip!.status;
    final statusInfo = _getStatusInfo(status);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusInfo['backgroundColor'],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusInfo['icon'], color: statusInfo['textColor'], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusInfo['text'],
              style: TextStyle(
                color: statusInfo['textColor'],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Mon voyage',
                style: TextStyle(
                  color: statusInfo['textColor'],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(TripStatus status) {
    switch (status) {
      case TripStatus.draft:
        return {
          'backgroundColor': Colors.grey.shade200,
          'textColor': Colors.grey.shade800,
          'icon': Icons.edit,
          'text': 'Brouillon - Non publié',
        };
      case TripStatus.pendingReview:
      case TripStatus.pendingApproval:
        return {
          'backgroundColor': Colors.orange.shade200,
          'textColor': Colors.orange.shade800,
          'icon': Icons.hourglass_empty,
          'text': 'En attente de validation',
        };
      case TripStatus.active:
        return {
          'backgroundColor': Colors.green.shade200,
          'textColor': Colors.green.shade800,
          'icon': Icons.check_circle,
          'text': 'Actif - Disponible pour réservation',
        };
      case TripStatus.rejected:
        return {
          'backgroundColor': Colors.red.shade200,
          'textColor': Colors.red.shade800,
          'icon': Icons.cancel,
          'text': 'Rejeté - Nécessite des modifications',
        };
      case TripStatus.booked:
        return {
          'backgroundColor': Colors.blue.shade200,
          'textColor': Colors.blue.shade800,
          'icon': Icons.bookmark,
          'text': 'Réservé - Prêt à partir',
        };
      case TripStatus.inProgress:
        return {
          'backgroundColor': Colors.indigo.shade200,
          'textColor': Colors.indigo.shade800,
          'icon': Icons.flight_takeoff,
          'text': 'En cours de voyage',
        };
      case TripStatus.completed:
        return {
          'backgroundColor': Colors.green.shade300,
          'textColor': Colors.green.shade900,
          'icon': Icons.check_circle_outline,
          'text': 'Voyage terminé avec succès',
        };
      case TripStatus.cancelled:
        return {
          'backgroundColor': Colors.red.shade100,
          'textColor': Colors.red.shade800,
          'icon': Icons.cancel_outlined,
          'text': 'Voyage annulé',
        };
      case TripStatus.paused:
        return {
          'backgroundColor': Colors.amber.shade200,
          'textColor': Colors.amber.shade800,
          'icon': Icons.pause_circle,
          'text': 'En pause temporaire',
        };
      case TripStatus.expired:
        return {
          'backgroundColor': Colors.grey.shade300,
          'textColor': Colors.grey.shade700,
          'icon': Icons.schedule,
          'text': 'Voyage expiré',
        };
      default:
        return {
          'backgroundColor': Colors.grey.shade200,
          'textColor': Colors.grey.shade800,
          'icon': Icons.info,
          'text': 'Statut inconnu',
        };
    }
  }

  Widget _buildTripHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.flight_takeoff,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_trip!.departureCity} → ${_trip!.arrivalCity}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_trip!.departureCountry} → ${_trip!.arrivalCountry}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetails() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations du voyage',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow(
              Icons.luggage,
              'Poids disponible',
              '${_trip!.availableWeightKg.toStringAsFixed(1)} kg',
            ),
            if (_trip!.totalBookedWeight > 0 || _trip!.availableWeightKg > 0)
              _buildCapacityInfoSection(),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.attach_money,
              'Prix par kg',
              '${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}',
            ),
            _buildDetailRow(
              Icons.account_balance_wallet,
              'Gain maximum',
              '${_trip!.totalEarningsPotential.toStringAsFixed(0)} ${_trip!.currency}',
            ),
            _buildDetailRow(
              Icons.schedule,
              'Durée',
              _trip!.durationDisplay,
            ),
            
            const SizedBox(height: 16),
            Text(
              'Détails du voyage',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildDetailRow(
              Icons.calendar_today,
              'Date de départ',
              _formatDateTime(_trip!.departureDate),
            ),
            _buildDetailRow(
              Icons.calendar_today,
              'Date d\'arrivée',
              _formatDateTime(_trip!.arrivalDate),
            ),
            _buildDetailRow(
              Icons.flight,
              'Transport',
              _getTransportTypeName(_trip!.transportType),
            ),
            
            if (_trip!.flightNumber?.isNotEmpty == true)
              _buildDetailRow(
                Icons.airplane_ticket,
                'Numéro de vol',
                _trip!.flightNumber!,
              ),
              
            if (_trip!.airline?.isNotEmpty == true)
              _buildDetailRow(
                Icons.business,
                'Compagnie',
                _trip!.airline!,
              ),
              
            _buildDetailRow(
              Icons.visibility,
              'Vues',
              _trip!.viewCount.toString(),
            ),
            
            if (_trip!.ticketVerified)
              _buildDetailRow(
                Icons.verified,
                'Billet vérifié',
                'Oui',
                valueColor: Colors.green,
              ),
              
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _trip!.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isOwner ? 'Actions disponibles' : 'Intéressé par ce voyage ?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isOwner 
                  ? 'Gérez votre annonce selon son statut.'
                  : _isAuthenticated 
                      ? 'Contactez le transporteur.'
                      : 'Connectez-vous pour plus d\'options.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isOwner) {
      return _buildOwnerActions();
    } else if (_isAuthenticated) {
      return _buildUserActions();
    } else {
      return _buildGuestActions();
    }
  }

  Widget _buildOwnerActions() {
    final status = _trip!.status;
    
    switch (status) {
      case TripStatus.draft:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _editTrip(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _submitForReview(),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text(
                      'Publier',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_canDeleteTrip()) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteTrip(),
                  icon: const Icon(Icons.delete),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        );

      case TripStatus.pendingReview:
      case TripStatus.pendingApproval:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.hourglass_empty, color: Colors.orange.shade600, size: 32),
              const SizedBox(height: 8),
              Text(
                'En attente de validation',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Votre voyage est en cours de révision par notre équipe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ],
          ),
        );
        
      case TripStatus.active:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pauseTrip(),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markAsBooked(),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Réservé'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelTrip(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markAsExpired(),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Expiré'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        );
        
      case TripStatus.paused:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reactivateTrip(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Réactiver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelTrip(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        );

      case TripStatus.booked:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: EllipsisButton.elevated(
                    onPressed: _isStartingJourney ? null : () => _startJourney(),
                    icon: _isStartingJourney 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.flight_takeoff),
                    text: _isStartingJourney ? 'Démarrage...' : 'Commencer',
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelTrip(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        );

      case TripStatus.inProgress:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.flight_takeoff, color: Colors.blue.shade600, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Voyage en cours',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bon voyage ! N\'oubliez pas de confirmer les livraisons.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _manageDeliveryCodes(),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Gérer les codes de livraison'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _completeDelivery(),
                icon: const Icon(Icons.check_circle),
                label: const Text('Terminer le voyage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
        
      case TripStatus.rejected:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.cancel, color: Colors.red.shade600, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Voyage rejeté',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modifiez et soumettez à nouveau.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _backToDraft(),
                icon: const Icon(Icons.edit),
                label: const Text('Modifier et remettre en brouillon'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      
      case TripStatus.completed:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
              const SizedBox(height: 8),
              Text(
                'Voyage terminé',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Félicitations ! Votre voyage s\'est bien déroulé.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green.shade700, fontSize: 12),
              ),
            ],
          ),
        );
      
      case TripStatus.cancelled:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Icon(Icons.cancel, color: Colors.grey.shade600, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Voyage annulé',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _duplicateTrip(),
                icon: const Icon(Icons.copy),
                label: const Text('Dupliquer ce voyage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case TripStatus.expired:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule, color: Colors.orange.shade600, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Voyage expiré',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _duplicateTrip(),
                icon: const Icon(Icons.copy),
                label: const Text('Dupliquer ce voyage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
        
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Statut non reconnu: ${status.value}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        );
    }
  }

  Widget _buildUserActions() {
    final canBook = _trip!.status != TripStatus.inProgress && 
                    _trip!.status != TripStatus.completed && 
                    _trip!.status != TripStatus.cancelled && 
                    _trip!.status != TripStatus.expired;
    
    return Column(
      children: [
        // Bouton principal "Réserver" ou message informatif
        if (canBook) 
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _createBookingRequest(),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Réserver ce transport'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else 
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600),
                const SizedBox(height: 8),
                Text(
                  _getBookingBlockedMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // Actions secondaires
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _contactOwner(),
                icon: const Icon(Icons.message),
                label: const Text('Contacter'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EllipsisButton.outlined(
                onPressed: () => _toggleFavorite(),
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                text: _isFavorite ? 'Favoris ✓' : 'Favoris',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuestActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login),
            label: const Text(
              'Se connecter',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/register'),
            icon: const Icon(Icons.person_add),
            label: const Text(
              'S\'inscrire',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  // Action handlers
  void _editTrip() {
    context.push('/trips/edit/${_trip!.id}');
  }

  void _publishTrip() async {
    try {
      // Publishing trip

      if (_trip == null) {
        _showMessage('Erreur: voyage non trouvé', Colors.red);
        return;
      }

      final tripService = TripService();
      final publishedTrip = await tripService.publishTrip(_trip!.id.toString());

      // Trip published successfully

      // Update local trip data
      setState(() {
        _trip = publishedTrip;
      });

      _showMessage('Annonce publiée avec succès !', Colors.green);

    } catch (e) {
      // Check if it's a Stripe account requirement error
      if (e is TripException && e.isStripeAccountRequired) {
        _showStripeRequiredDialog(e);
      } else {
        _showMessage('Erreur lors de la publication: $e', Colors.red);
      }
    }
  }

  void _pauseTrip() async {
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.pauseTrip(_trip!.id.toString());
      
      _showMessage('Annonce mise en pause avec succès !', Colors.orange);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors de la mise en pause: $e', Colors.red);
    }
  }

  void _resumeTrip() async {
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.resumeTrip(_trip!.id.toString());
      
      _showMessage('Annonce réactivée avec succès !', Colors.green);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors de la réactivation: $e', Colors.red);
    }
  }

  void _cancelTrip() async {
    if (_trip == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler l\'annonce'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette annonce ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final tripService = TripService();
      await tripService.cancelTrip(_trip!.id.toString());
      
      _showMessage('Annonce annulée avec succès', Colors.orange);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors de l\'annulation: $e', Colors.red);
    }
  }

  void _duplicateTrip() async {
    try {
      // Duplicate button pressed
      // Duplicating trip
      
      if (_trip == null) {
        _showMessage('Erreur: voyage non trouvé', Colors.red);
        return;
      }
      
      final tripService = TripService();
      final duplicatedTrip = await tripService.duplicateTrip(_trip!.id.toString());
      
      // Duplication successful
      _showMessage('Annonce dupliquée avec succès', Colors.green);
      
      // Optionally navigate to the new trip or refresh
      
    } catch (e) {
      // Duplication failed
      _showMessage('Erreur lors de la duplication: $e', Colors.red);
    }
  }

  void _deleteTrip() async {
    if (_trip == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette annonce ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final tripService = TripService();
      await tripService.deleteTrip(_trip!.id.toString());
      
      _showMessage('Annonce supprimée avec succès', Colors.green);
      
      // Navigate back
      if (mounted && context.canPop()) {
        context.pop();
      }
      
    } catch (e) {
      _showMessage('Erreur lors de la suppression: $e', Colors.red);
    }
  }

  bool _canDeleteTrip() {
    if (_trip == null) return false;
    
    // Règles de suppression selon le diagramme d'état:
    // On peut supprimer uniquement dans ces états:
    // - draft (brouillon)
    // - rejected (rejeté) 
    // - paused (mis en pause)
    // - cancelled (annulé - déjà terminé mais on peut nettoyer)
    
    switch (_trip!.status) {
      case TripStatus.draft:
      case TripStatus.rejected: 
      case TripStatus.paused:
      case TripStatus.cancelled:
        return true;
      default:
        return false;
    }
  }

  void _contactOwner() {
    if (_trip == null) {
      _showMessage('Erreur: voyage non trouvé', Colors.red);
      return;
    }

    if (!_isAuthenticated) {
      _showMessage('Veuillez vous connecter pour contacter le propriétaire', Colors.orange);
      return;
    }

    if (_isOwner) {
      _showMessage('Vous ne pouvez pas vous contacter vous-même', Colors.orange);
      return;
    }

    // Navigate to conversation screen
    context.pushNamed(
      'conversation',
      queryParameters: {
        'tripId': _trip!.id.toString(),
        'tripOwnerId': _trip!.userId.toString(),
        'tripTitle': 'Voyage ${_trip!.departureCity} → ${_trip!.arrivalCity}',
      },
    );
  }

  void _toggleFavorite() async {
    // Toggle favorite clicked
    
    if (!_isAuthenticated) {
      _showMessage('Veuillez vous connecter pour ajouter aux favoris', Colors.orange);
      return;
    }
    
    if (_isOwner) {
      _showMessage('Vous ne pouvez pas ajouter votre propre voyage aux favoris', Colors.orange);
      return;
    }
    
    try {
      final result = await FavoritesService.instance.toggleFavorite(widget.tripId);
      // Toggle result received
      
      if (result['success'] == true) {
        final newFavoriteState = result['isFavorite'] ?? false;
        // Updating favorite state
        
        setState(() {
          _isFavorite = newFavoriteState;
        });
        
        // State updated
        
        _showMessage(
          _isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris', 
          Colors.green
        );
      } else {
        _showMessage('Erreur lors de la mise à jour des favoris', Colors.red);
      }
    } catch (e) {
      // Toggle error
      _showMessage('Erreur lors de la mise à jour des favoris', Colors.red);
    }
  }

  void _createBookingRequest() async {
    if (_trip == null) return;
    
    try {
      // Naviguer vers l'écran de création de réservation
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBookingScreen(trip: _trip!),
        ),
      );
      
      // Note: La confirmation de succès est déjà gérée par CreateBookingScreen
      // Pas besoin de double confirmation ici
      
    } catch (e) {
      _showMessage('Erreur lors de la création de la réservation: $e', Colors.red);
    }
  }

  // === NEW STATUS TRANSITION ACTIONS ===
  
  void _submitForReview() async {
    if (_trip == null) return;

    try {
      final tripService = TripService();
      await tripService.submitForReview(_trip!.id.toString());

      _showMessage('Voyage soumis pour révision avec succès !', Colors.green);

      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();

    } catch (e) {
      // Check if it's a Stripe account requirement error
      if (e is TripException && e.isStripeAccountRequired) {
        _showStripeRequiredDialog(e);
      } else {
        _showMessage('Erreur lors de la soumission: $e', Colors.red);
      }
    }
  }

  void _showStripeRequiredDialog(TripException error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.payment,
            color: Colors.orange,
            size: 48,
          ),
          title: const Text(
            'Configuration Stripe requise',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error.message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stripe vous permet de recevoir des paiements de manière sécurisée.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to Wallet screen for Stripe setup
                context.push('/profile/wallet');
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Configurer Stripe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _markAsBooked() async {
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.markAsBooked(_trip!.id.toString());
      
      _showMessage('Voyage marqué comme réservé !', Colors.green);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors du marquage: $e', Colors.red);
    }
  }
  
  void _markAsExpired() async {
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.markAsExpired(_trip!.id.toString());
      
      _showMessage('Voyage marqué comme expiré', Colors.orange);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors du marquage: $e', Colors.red);
    }
  }
  
  void _reactivateTrip() async {
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.reactivateTrip(_trip!.id.toString());
      
      _showMessage('Voyage réactivé avec succès !', Colors.green);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors de la réactivation: $e', Colors.red);
    }
  }
  
  void _startJourney() async {
    if (_trip == null || _isStartingJourney) return;

    setState(() {
      _isStartingJourney = true;
    });

    try {
      final tripService = TripService();
      final result = await tripService.startTrip(_trip!.id.toString());

      if (result['success'] == true) {
        _showMessage('Voyage commencé ! Bon voyage !', Colors.blue);

        // Refresh trip data
        setState(() {
          _hasLoaded = false;
          _isStartingJourney = false;
        });
        _loadDataOnce();
      } else {
        setState(() {
          _isStartingJourney = false;
        });
        _showMessage(result['error'] ?? 'Erreur lors du démarrage', Colors.red);
      }

    } catch (e) {
      setState(() {
        _isStartingJourney = false;
      });
      _showMessage('Erreur lors du démarrage: $e', Colors.red);
    }
  }
  
  void _completeDelivery() async {
    if (_trip == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer le voyage'),
        content: const Text('Confirmez-vous que toutes les livraisons ont été effectuées avec succès ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final tripService = TripService();
      final result = await tripService.completeTrip(_trip!.id.toString());

      if (result['success'] == true) {
        _showMessage('Voyage terminé avec succès ! 🎉', Colors.green);

        // Refresh trip data
        setState(() {
          _hasLoaded = false;
        });
        _loadDataOnce();
      } else {
        // Check if there are missing deliveries
        if (result['missing_deliveries'] != null) {
          final missingCount = result['missing_count'] ?? 0;
          final missingDeliveries = result['missing_deliveries'] as List<dynamic>;

          // Show dialog with missing deliveries
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Livraisons manquantes'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous ne pouvez pas terminer le voyage car $missingCount livraison(s) n\'ont pas été confirmées:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...missingDeliveries.map((delivery) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Réservation #${delivery['booking_id']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (delivery['sender_name'] != null)
                                    Text('Client: ${delivery['sender_name']}'),
                                  if (delivery['package_description'] != null)
                                    Text('Colis: ${delivery['package_description']}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    const Text(
                      'Veuillez générer les codes de livraison et demander aux clients de les valider.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          _showMessage(result['error'] ?? 'Erreur lors de la finalisation', Colors.red);
        }
      }

    } catch (e) {
      _showMessage('Erreur lors de la finalisation: $e', Colors.red);
    }
  }

  void _manageDeliveryCodes() async {
    if (_trip == null) return;

    // Check if trip has bookings
    if (_trip!.bookingCount == 0) {
      _showMessage('Aucune réservation pour ce voyage', Colors.orange);
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Load trip bookings
      final tripService = TripService();
      final bookings = await tripService.getTripBookings(_trip!.id.toString());

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Filter confirmed bookings only (accepted, paid, in transit, delivered, completed)
      final confirmedBookings = bookings
          .where((booking) =>
            booking.status == BookingStatus.accepted ||
            booking.status == BookingStatus.paymentPending ||
            booking.status == BookingStatus.paymentAuthorized ||
            booking.status == BookingStatus.paymentConfirmed ||
            booking.status == BookingStatus.paid ||
            booking.status == BookingStatus.inTransit ||
            booking.status == BookingStatus.delivered ||
            booking.status == BookingStatus.completed
          )
          .toList();

      if (confirmedBookings.isEmpty) {
        _showMessage('Aucune réservation confirmée pour ce voyage', Colors.orange);
        return;
      }

      // Navigate to delivery codes screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransporterDeliveryCodeScreen(
              bookings: confirmedBookings,
            ),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      _showMessage('Erreur lors du chargement des réservations: $e', Colors.red);
    }
  }

  void _backToDraft() async {
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.backToDraft(_trip!.id.toString());
      
      _showMessage('Voyage remis en brouillon pour modification', Colors.blue);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors de la remise en brouillon: $e', Colors.red);
    }
  }


  Widget _buildSpecialNotesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Notes spéciales',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _trip!.specialNotes!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    final uniqueImages = _trip?.uniqueImages;
    if (uniqueImages == null || uniqueImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Images du voyage',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: uniqueImages.length,
              itemBuilder: (context, index) {
                final image = uniqueImages[index];
                return Container(
                  width: 300,
                  margin: EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Image.network(
                          image.url,
                          width: 300,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 300,
                              height: 200,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Error loading trip image
                            return Container(
                              width: 300,
                              height: 200,
                              color: Colors.grey[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, size: 40, color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Erreur de chargement',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (image.isPrimary)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Principal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_trip!.imageCount} image${_trip!.imageCount > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final months = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    
    return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year} à ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _getTransportTypeName(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'plane':
      case 'flight':
        return 'Avion';
      case 'train':
        return 'Train';
      case 'bus':
        return 'Bus';
      case 'car':
        return 'Voiture';
      default:
        return transportType;
    }
  }

  String _getBookingBlockedMessage() {
    switch (_trip!.status) {
      case TripStatus.inProgress:
        return 'Ce voyage est en cours et n\'accepte plus de nouvelles réservations.';
      case TripStatus.completed:
        return 'Ce voyage est terminé.';
      case TripStatus.cancelled:
        return 'Ce voyage a été annulé.';
      case TripStatus.expired:
        return 'Ce voyage a expiré.';
      default:
        return 'Ce voyage n\'accepte plus de réservations.';
    }
  }

  Widget _buildCapacityInfoSection() {
    if (_trip == null) {
      return const SizedBox.shrink();
    }

    final bookedWeight = _trip!.totalBookedWeight;
    final availableWeight = _trip!.availableWeightKg;
    final totalCapacity = availableWeight + bookedWeight;
    final bookingRate = totalCapacity > 0 ? (bookedWeight / totalCapacity) * 100 : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: bookedWeight > 0 ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bookedWeight > 0 ? Colors.orange.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bookedWeight > 0 ? Icons.info : Icons.check_circle,
                size: 16,
                color: bookedWeight > 0 ? Colors.orange.shade600 : Colors.green.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'État des réservations',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: bookedWeight > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capacité totale:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${totalCapacity.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (bookedWeight > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Déjà réservé:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  '${bookedWeight.toStringAsFixed(1)} kg (${bookingRate.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Encore disponible:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${availableWeight.toStringAsFixed(1)} kg',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: availableWeight > 0 ? Colors.green.shade600 : Colors.red.shade600,
                ),
              ),
            ],
          ),
          if (bookedWeight > 0) ...[
            const SizedBox(height: 8),
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.grey.shade300,
              ),
              child: LinearProgressIndicator(
                value: bookingRate / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  bookingRate >= 90 ? Colors.red.shade400 :
                  bookingRate >= 70 ? Colors.orange.shade400 :
                  Colors.green.shade400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}