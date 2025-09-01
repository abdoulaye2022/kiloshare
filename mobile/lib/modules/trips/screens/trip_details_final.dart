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
  String? _currentUserId;
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
          isFavorite = await FavoritesService.instance.isFavorite(widget.tripId);
          print('TripDetailsFinal: Trip is favorite: $isFavorite');
        } catch (e) {
          print('TripDetailsFinal: Error checking favorite status: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _currentUserId = userId;
          _trip = trip;
          _isOwner = trip.userId == userId;
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
                    onPressed: () => _publishTrip(),
                    icon: const Icon(Icons.publish),
                    label: const Text('Publier'),
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
        
      case TripStatus.active:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editTrip(),
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pauseTrip(),
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
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
                    onPressed: () => _resumeTrip(),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
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
        
      case TripStatus.rejected:
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
                    onPressed: () => _duplicateTrip(),
                    icon: const Icon(Icons.copy),
                    label: const Text('Dupliquer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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
      
      case TripStatus.cancelled:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => _duplicateTrip(),
              icon: const Icon(Icons.copy),
              label: const Text('Dupliquer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
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
        
      default:
        return ElevatedButton.icon(
          onPressed: () => _duplicateTrip(),
          icon: const Icon(Icons.copy),
          label: const Text('Dupliquer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
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

  void _pauseTrip() {
    _showMessage('Annonce mise en pause', Colors.orange);
  }

  void _resumeTrip() {
    _showMessage('Annonce réactivée', Colors.green);
  }

  void _cancelTrip() {
    _showMessage('Annonce annulée', Colors.red);
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
    if (!_isAuthenticated) {
      _showMessage('Veuillez vous connecter pour ajouter aux favoris', Colors.orange);
      return;
    }
    
    if (_isOwner) {
      _showMessage('Vous ne pouvez pas ajouter votre propre voyage aux favoris', Colors.orange);
      return;
    }
    
    try {
      final success = await FavoritesService.instance.toggleFavorite(widget.tripId);
      if (success) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
        _showMessage(
          _isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris', 
          Colors.green
        );
      } else {
        _showMessage('Erreur lors de la mise à jour des favoris', Colors.red);
      }
    } catch (e) {
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

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}