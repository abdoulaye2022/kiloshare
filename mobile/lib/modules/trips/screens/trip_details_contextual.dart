import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../../auth/services/auth_service.dart';

class TripDetailsContextual extends StatefulWidget {
  final String tripId;

  const TripDetailsContextual({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsContextual> createState() => _TripDetailsContextualState();
}

class _TripDetailsContextualState extends State<TripDetailsContextual> with AutomaticKeepAliveClientMixin {
  Trip? _trip;
  bool _isLoading = true;
  String? _error;
  bool _isAuthenticated = false;
  String? _currentUserId;
  bool _isOwner = false;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    print('TripDetailsContextual: Loading data for trip ${widget.tripId}');
    
    // Load auth status and trip in parallel
    final futures = await Future.wait([
      _getAuthStatus(),
      _getTripData(),
    ]);
    
    final authData = futures[0] as Map<String, dynamic>;
    final tripData = futures[1] as Map<String, dynamic>;
    
    if (!mounted) return;
    
    setState(() {
      _isAuthenticated = authData['isAuthenticated'] as bool;
      _currentUserId = authData['userId'] as String?;
      _trip = tripData['trip'] as Trip?;
      _error = tripData['error'] as String?;
      _isOwner = _trip != null && _currentUserId != null && _trip!.userId == _currentUserId;
      _isLoading = false;
    });
    
    print('TripDetailsContextual: Data loaded - Auth: $_isAuthenticated, Owner: $_isOwner, Status: ${_trip?.status}');
  }

  Future<Map<String, dynamic>> _getAuthStatus() async {
    try {
      final token = await AuthService.instance.getStoredToken();
      final isAuth = token != null && !AuthService.instance.isTokenExpired(token);
      
      String? userId;
      if (isAuth) {
        try {
          final user = await AuthService.instance.getCurrentUser();
          userId = user?.id.toString();
        } catch (e) {
          print('TripDetailsContextual: Error getting current user: $e');
        }
      }
      
      return {
        'isAuthenticated': isAuth,
        'userId': userId,
      };
    } catch (e) {
      print('TripDetailsContextual: Auth check error: $e');
      return {
        'isAuthenticated': false,
        'userId': null,
      };
    }
  }

  Future<Map<String, dynamic>> _getTripData() async {
    try {
      final tripService = TripService();
      final trip = await tripService.getTripById(widget.tripId);
      return {'trip': trip, 'error': null};
    } catch (e) {
      print('TripDetailsContextual: Trip load error: $e');
      return {'trip': null, 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _isOwner && _trip != null ? [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => _buildMenuItems(),
            icon: const Icon(Icons.more_vert),
          ),
        ] : null,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des détails...'),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadData();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_trip == null) {
      return const Center(
        child: Text('Voyage non trouvé'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          _buildStatusBanner(),
          
          const SizedBox(height: 16),
          
          // Trip header card
          _buildTripHeader(),

          const SizedBox(height: 16),

          // Trip details card
          _buildTripDetails(),

          if (_trip!.description?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildDescription(),
          ],

          const SizedBox(height: 16),

          // Action buttons card
          _buildActionButtons(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = _trip!.status;
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String statusText;

    switch (status) {
      case TripStatus.draft:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        icon = Icons.edit;
        statusText = 'Brouillon - Non publié';
        break;
      case TripStatus.pendingReview:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.hourglass_empty;
        statusText = 'En attente de validation';
        break;
      case TripStatus.active:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        statusText = 'Actif - Disponible pour réservation';
        break;
      case TripStatus.rejected:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        statusText = 'Rejeté - Nécessite des modifications';
        break;
      case TripStatus.booked:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.bookmark;
        statusText = 'Réservé - Réservation confirmée';
        break;
      case TripStatus.inProgress:
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        icon = Icons.flight_takeoff;
        statusText = 'En cours - Voyage commencé';
        break;
      case TripStatus.completed:
        backgroundColor = Colors.green.shade200;
        textColor = Colors.green.shade900;
        icon = Icons.done_all;
        statusText = 'Terminé - Livraison effectuée';
        break;
      case TripStatus.cancelled:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.block;
        statusText = 'Annulé';
        break;
      case TripStatus.paused:
        backgroundColor = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        icon = Icons.pause_circle;
        statusText = 'Mis en pause';
        break;
      case TripStatus.expired:
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade600;
        icon = Icons.schedule;
        statusText = 'Expiré - Date dépassée';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        icon = Icons.info;
        statusText = status.value;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                if (_isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Mon voyage',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
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
            
            _buildInfoRow(
              Icons.luggage,
              'Poids disponible',
              '${_trip!.availableWeightKg.toStringAsFixed(1)} kg',
            ),
            _buildInfoRow(
              Icons.attach_money,
              'Prix par kg',
              '${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}',
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Date de départ',
              _formatDate(_trip!.departureDate),
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Date d\'arrivée',
              _formatDate(_trip!.arrivalDate),
            ),
            
            if (_trip!.flightNumber?.isNotEmpty == true)
              _buildInfoRow(
                Icons.airplane_ticket,
                'Numéro de vol',
                _trip!.flightNumber!,
              ),
              
            if (_trip!.airline?.isNotEmpty == true)
              _buildInfoRow(
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
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
            if (_isOwner)
              Text(
                'Gérez votre annonce selon son statut actuel.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              )
            else
              Text(
                _isAuthenticated
                    ? 'Contactez le transporteur pour réserver votre espace.'
                    : 'Connectez-vous pour contacter le transporteur.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            const SizedBox(height: 16),
            _buildContextualActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildContextualActions() {
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
    List<Widget> actions = [];

    switch (status) {
      case TripStatus.draft:
        actions = [
          _buildActionButton(
            'Modifier',
            Icons.edit,
            Colors.blue,
            () => _editTrip(),
            isOutlined: true,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Publier',
            Icons.publish,
            Colors.green,
            () => _publishTrip(),
          ),
        ];
        break;

      case TripStatus.pendingReview:
      case TripStatus.pendingApproval:
        actions = [
          _buildActionButton(
            'Modifier',
            Icons.edit,
            Colors.blue,
            () => _editTrip(),
            isOutlined: true,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Annuler',
            Icons.cancel,
            Colors.red,
            () => _cancelTrip(),
            isOutlined: true,
          ),
        ];
        break;

      case TripStatus.rejected:
        actions = [
          _buildActionButton(
            'Modifier',
            Icons.edit,
            Colors.blue,
            () => _editTrip(),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Supprimer',
            Icons.delete,
            Colors.red,
            () => _deleteTrip(),
            isOutlined: true,
          ),
        ];
        break;

      case TripStatus.active:
        actions = [
          _buildActionButton(
            'Modifier',
            Icons.edit,
            Colors.blue,
            () => _editTrip(),
            isOutlined: true,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Pause',
            Icons.pause,
            Colors.orange,
            () => _pauseTrip(),
            isOutlined: true,
          ),
        ];
        break;

      case TripStatus.paused:
        actions = [
          _buildActionButton(
            'Réactiver',
            Icons.play_arrow,
            Colors.green,
            () => _resumeTrip(),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Annuler',
            Icons.cancel,
            Colors.red,
            () => _cancelTrip(),
            isOutlined: true,
          ),
        ];
        break;

      case TripStatus.booked:
        actions = [
          _buildActionButton(
            'Marquer en cours',
            Icons.flight_takeoff,
            Colors.purple,
            () => _markInProgress(),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Annuler',
            Icons.cancel,
            Colors.red,
            () => _cancelTrip(),
            isOutlined: true,
          ),
        ];
        break;

      case TripStatus.inProgress:
        actions = [
          _buildActionButton(
            'Marquer terminé',
            Icons.done_all,
            Colors.green,
            () => _completeTrip(),
          ),
        ];
        break;

      case TripStatus.completed:
      case TripStatus.cancelled:
      case TripStatus.expired:
        actions = [
          _buildActionButton(
            'Dupliquer',
            Icons.copy,
            Colors.blue,
            () => _duplicateTrip(),
            isOutlined: true,
          ),
        ];
        break;
    }

    return Row(
      children: [
        ...actions,
        if (actions.isNotEmpty) const Spacer(),
      ],
    );
  }

  Widget _buildUserActions() {
    if (_trip!.status == TripStatus.active) {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'Contacter',
              Icons.message,
              Colors.blue,
              () => _contactOwner(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Sauvegarder',
              Icons.bookmark_border,
              Colors.green,
              () => _saveTrip(),
              isOutlined: true,
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Ce voyage n\'est pas disponible pour réservation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
  }

  Widget _buildGuestActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Se connecter',
            Icons.login,
            Colors.blue,
            () => context.push('/login'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'S\'inscrire',
            Icons.person_add,
            Colors.green,
            () => context.push('/register'),
            isOutlined: true,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      );
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    List<PopupMenuEntry<String>> items = [];
    
    items.add(
      const PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            SizedBox(width: 8),
            Text('Dupliquer'),
          ],
        ),
      ),
    );
    
    if (_trip!.status == TripStatus.draft || _trip!.status == TripStatus.rejected) {
      items.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }
    
    return items;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Action handlers
  void _editTrip() {
    context.push('/trips/edit/${_trip!.id}');
  }

  void _publishTrip() {
    _showConfirmDialog(
      'Publier l\'annonce',
      'Voulez-vous publier cette annonce ? Elle sera soumise pour validation.',
      () => _performAction('publish'),
    );
  }

  void _pauseTrip() {
    _showConfirmDialog(
      'Mettre en pause',
      'Voulez-vous mettre cette annonce en pause ? Elle ne sera plus visible.',
      () => _performAction('pause'),
    );
  }

  void _resumeTrip() {
    _showConfirmDialog(
      'Réactiver l\'annonce',
      'Voulez-vous réactiver cette annonce ?',
      () => _performAction('resume'),
    );
  }

  void _cancelTrip() {
    _showConfirmDialog(
      'Annuler le voyage',
      'Voulez-vous annuler ce voyage ? Cette action est définitive.',
      () => _performAction('cancel'),
    );
  }

  void _deleteTrip() {
    _showConfirmDialog(
      'Supprimer l\'annonce',
      'Voulez-vous supprimer définitivement cette annonce ?',
      () => _performAction('delete'),
    );
  }

  void _duplicateTrip() {
    _performAction('duplicate');
  }

  void _markInProgress() {
    _performAction('markInProgress');
  }

  void _completeTrip() {
    _showConfirmDialog(
      'Marquer comme terminé',
      'Confirmez-vous que ce voyage est terminé ?',
      () => _performAction('complete'),
    );
  }

  void _contactOwner() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité de contact bientôt disponible'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _saveTrip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voyage ajouté aux favoris'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'duplicate':
        _duplicateTrip();
        break;
      case 'delete':
        _deleteTrip();
        break;
    }
  }

  void _showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAction(String action) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action "$action" en cours...'),
        ),
      );
      
      // TODO: Implement actual API calls
      await Future.delayed(const Duration(seconds: 1));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action "$action" effectuée avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload data to reflect changes
      if (action != 'duplicate' && action != 'delete') {
        _loadData();
      } else if (action == 'delete') {
        context.pop(); // Go back if trip was deleted
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}