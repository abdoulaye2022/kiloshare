import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../services/favorites_service.dart';
import '../../../widgets/ellipsis_button.dart';
import '../../auth/services/auth_service.dart';
import '../../booking/screens/create_booking_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDataOnce();
  }

  Future<void> _loadDataOnce() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    
    print('=== TRIP DETAILS DEBUG START ===');
    print('TripDetailsFinal: Loading data for trip ID: ${widget.tripId}');
    print('TripDetailsFinal: Trip ID type: ${widget.tripId.runtimeType}');
    print('TripDetailsFinal: Trip ID length: ${widget.tripId.length}');
    
    try {
      // Check auth status
      final token = await AuthService.instance.getStoredToken();
      final isAuth = token != null && !AuthService.instance.isTokenExpired(token);
      print('TripDetailsFinal: Authentication status - isAuth: $isAuth, hasToken: ${token != null}');
      
      String? userId;
      if (isAuth) {
        try {
          final user = await AuthService.instance.getCurrentUser();
          userId = user?.id.toString();
          print('TripDetailsFinal: Current user ID: $userId');
        } catch (e) {
          print('TripDetailsFinal: Error getting current user: $e');
        }
      } else {
        print('TripDetailsFinal: No authentication - proceeding with public access');
      }

      // Load trip data
      final tripService = TripService();
      print('TripDetailsFinal: About to call getTripById with ID: "${widget.tripId}"');
      
      final trip = await tripService.getTripById(widget.tripId);
      
      print('TripDetailsFinal: Trip loaded successfully!');
      print('TripDetailsFinal: - Trip ID: ${trip.id}');
      print('TripDetailsFinal: - Trip Status: ${trip.status}');
      print('TripDetailsFinal: - Trip Owner ID: ${trip.userId}');
      print('TripDetailsFinal: - Current User ID: $userId');
      print('TripDetailsFinal: - Is Owner: ${trip.userId == userId}');
      print('TripDetailsFinal: - Departure: ${trip.departureCity} → ${trip.arrivalCity}');
      print('=== TRIP DETAILS DEBUG SUCCESS ===');
      
      // Check favorite status if authenticated and not owner
      bool isFavorite = false;
      if (isAuth && userId != null && trip.userId != userId) {
        try {
          print('TripDetailsFinal: Checking favorite status for trip: ${widget.tripId}');
          isFavorite = await FavoritesService.instance.isFavorite(widget.tripId);
          print('TripDetailsFinal: Trip is favorite: $isFavorite');
        } catch (e) {
          print('TripDetailsFinal: Error checking favorite status: $e');
        }
      } else {
        print('TripDetailsFinal: Skipping favorite check - isAuth: $isAuth, isOwner: ${trip.userId == userId}');
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
      print('=== TRIP DETAILS DEBUG ERROR ===');
      print('TripDetailsFinal: Error loading trip data');
      print('TripDetailsFinal: - Requested Trip ID: "${widget.tripId}"');
      print('TripDetailsFinal: - Error Type: ${e.runtimeType}');
      print('TripDetailsFinal: - Error Message: $e');
      print('TripDetailsFinal: - Error String Contains "Trip not found": ${e.toString().contains('Trip not found')}');
      print('=== TRIP DETAILS DEBUG ERROR END ===');
      
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
          'text': 'Actif - Disponible',
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
          'text': 'Réservé',
        };
      case TripStatus.paused:
        return {
          'backgroundColor': Colors.amber.shade200,
          'textColor': Colors.amber.shade800,
          'icon': Icons.pause_circle,
          'text': 'En pause',
        };
      default:
        return {
          'backgroundColor': Colors.grey.shade200,
          'textColor': Colors.grey.shade800,
          'icon': Icons.info,
          'text': status.value,
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
            _buildDetailRow(
              Icons.attach_money,
              'Prix par kg',
              '${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}',
            ),
            
            if (_trip!.flightNumber?.isNotEmpty == true)
              _buildDetailRow(
                Icons.airplane_ticket,
                'Vol',
                _trip!.flightNumber!,
              ),
              
            if (_trip!.airline?.isNotEmpty == true)
              _buildDetailRow(
                Icons.business,
                'Compagnie',
                _trip!.airline!,
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
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
                    icon: const Icon(Icons.send),
                    label: const Text('Soumettre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                  child: ElevatedButton.icon(
                    onPressed: () => _startJourney(),
                    icon: const Icon(Icons.flight_takeoff),
                    label: const Text('Commencer'),
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
                    'Bon voyage ! N\'oubliez pas de confirmer la livraison.',
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
                onPressed: () => _completeDelivery(),
                icon: const Icon(Icons.check_circle),
                label: const Text('Marquer comme livré'),
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
    return Column(
      children: [
        // Bouton principal "Réserver"
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
            label: const Text('Se connecter'),
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
            label: const Text('S\'inscrire'),
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
      print('=== DEBUG: Publishing trip ${_trip?.id} ===');
      
      if (_trip == null) {
        _showMessage('Erreur: voyage non trouvé', Colors.red);
        return;
      }
      
      final tripService = TripService();
      final publishedTrip = await tripService.publishTrip(_trip!.id.toString());
      
      print('DEBUG: Trip published successfully');
      
      // Update local trip data
      setState(() {
        _trip = publishedTrip;
      });
      
      _showMessage('Annonce publiée avec succès !', Colors.green);
      
    } catch (e) {
      print('ERROR: Failed to publish trip: $e');
      _showMessage('Erreur lors de la publication: $e', Colors.red);
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
      print('=== DEBUG DUPLICATE BUTTON PRESSED ===');
      print('Trip ID: ${_trip?.id}');
      
      if (_trip == null) {
        _showMessage('Erreur: voyage non trouvé', Colors.red);
        return;
      }
      
      final tripService = TripService();
      final duplicatedTrip = await tripService.duplicateTrip(_trip!.id.toString());
      
      print('Duplication successful, new trip ID: ${duplicatedTrip.id}');
      _showMessage('Annonce dupliquée avec succès', Colors.green);
      
      // Optionally navigate to the new trip or refresh
      
    } catch (e) {
      print('Duplication failed: $e');
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
    _showMessage('Fonctionnalité de contact bientôt disponible', Colors.blue);
  }

  void _toggleFavorite() async {
    print('TripDetailsFinal: Toggle favorite clicked - current state: $_isFavorite');
    
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
      print('TripDetailsFinal: Toggle result: $result');
      
      if (result['success'] == true) {
        final newFavoriteState = result['isFavorite'] ?? false;
        print('TripDetailsFinal: Updating state from $_isFavorite to $newFavoriteState');
        
        setState(() {
          _isFavorite = newFavoriteState;
        });
        
        print('TripDetailsFinal: State updated - new _isFavorite: $_isFavorite');
        
        _showMessage(
          _isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris', 
          Colors.green
        );
      } else {
        _showMessage('Erreur lors de la mise à jour des favoris', Colors.red);
      }
    } catch (e) {
      print('TripDetailsFinal: Toggle error: $e');
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
      
      if (result == true) {
        _showMessage('Demande de réservation envoyée avec succès!', Colors.green);
      }
      
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
      _showMessage('Erreur lors de la soumission: $e', Colors.red);
    }
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
    if (_trip == null) return;
    
    try {
      final tripService = TripService();
      await tripService.startJourney(_trip!.id.toString());
      
      _showMessage('Voyage commencé ! Bon voyage !', Colors.blue);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors du démarrage: $e', Colors.red);
    }
  }
  
  void _completeDelivery() async {
    if (_trip == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la livraison'),
        content: const Text('Confirmez-vous que la livraison a été effectuée avec succès ?'),
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
      await tripService.completeDelivery(_trip!.id.toString());
      
      _showMessage('Livraison terminée avec succès ! 🎉', Colors.green);
      
      // Refresh trip data
      setState(() {
        _hasLoaded = false;
      });
      _loadDataOnce();
      
    } catch (e) {
      _showMessage('Erreur lors de la finalisation: $e', Colors.red);
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

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}