import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_token_service.dart';
import '../models/trip_model.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  Trip? _trip;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trip = await AuthTokenService.instance.tripService.getTripById(widget.tripId);
      setState(() {
        _trip = trip;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du voyage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _trip != null ? [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Modifier'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Partager'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ] : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_trip == null) {
      return _buildNotFoundState();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTripHeader(),
          _buildTripInfo(),
          _buildPricingInfo(),
          _buildFlightInfo(),
          _buildRestrictionsInfo(),
          _buildContactInfo(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTripHeader() {
    final trip = _trip!;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight_takeoff,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.routeDisplay,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(trip.status),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateTimeInfo(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TripStatus status) {
    Color color;
    String text;

    switch (status) {
      case TripStatus.draft:
        color = Colors.orange;
        text = 'Brouillon';
        break;
      case TripStatus.pendingApproval:
        color = Colors.amber;
        text = 'En attente d\'approbation';
        break;
      case TripStatus.published:
        color = Colors.green;
        text = 'Publié';
        break;
      case TripStatus.rejected:
        color = Colors.red;
        text = 'Rejeté';
        break;
      case TripStatus.flaggedForReview:
        color = Colors.purple;
        text = 'Signalé pour révision';
        break;
      case TripStatus.completed:
        color = Colors.blue;
        text = 'Terminé';
        break;
      case TripStatus.cancelled:
        color = Colors.red;
        text = 'Annulé';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDateTimeInfo() {
    final trip = _trip!;
    final dateFormatter = DateFormat('dd MMM yyyy', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm', 'fr_FR');
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Départ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateFormatter.format(trip.departureDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                timeFormatter.format(trip.departureDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.8)),
              const SizedBox(height: 4),
              Text(
                trip.durationDisplay,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Arrivée',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateFormatter.format(trip.arrivalDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                timeFormatter.format(trip.arrivalDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripInfo() {
    return _buildSection(
      'Informations du voyage',
      [
        if (_trip!.description != null)
          _buildInfoRow('Description', _trip!.description!),
        if (_trip!.specialNotes != null)
          _buildInfoRow('Notes spéciales', _trip!.specialNotes!),
      ],
    );
  }

  Widget _buildPricingInfo() {
    final trip = _trip!;
    
    return _buildSection(
      'Tarifs et capacité',
      [
        _buildInfoRow('Poids disponible', '${trip.availableWeightKg.toStringAsFixed(1)} kg'),
        _buildInfoRow('Prix par kg', '${trip.pricePerKg.toStringAsFixed(2)} ${trip.currency}'),
        _buildInfoRow('Gain maximum', '${trip.totalEarningsPotential.toStringAsFixed(0)} ${trip.currency}'),
      ],
    );
  }

  Widget _buildFlightInfo() {
    final trip = _trip!;
    
    if (trip.airline == null && trip.flightNumber == null) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      'Informations du vol',
      [
        if (trip.airline != null)
          _buildInfoRow('Compagnie aérienne', trip.airline!),
        if (trip.flightNumber != null)
          _buildInfoRow('Numéro de vol', trip.flightNumber!),
        if (trip.ticketVerified)
          _buildInfoRow('Billet', 'Vérifié ✓', textColor: Colors.green),
      ],
    );
  }

  Widget _buildRestrictionsInfo() {
    // TODO: Implement restrictions display when data is available
    return const SizedBox.shrink();
  }

  Widget _buildContactInfo() {
    final trip = _trip!;
    
    if (trip.user == null) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      'Transporteur',
      [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: trip.user!.profilePicture != null
                ? NetworkImage(trip.user!.profilePicture!)
                : null,
            child: trip.user!.profilePicture == null
                ? Text(trip.user!.initials)
                : null,
          ),
          title: Row(
            children: [
              Text(trip.user!.displayName),
              if (trip.user!.isVerified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, size: 16, color: Colors.blue[600]),
              ],
            ],
          ),
          subtitle: const Text('Transporteur'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 16, color: Colors.amber[600]),
              const SizedBox(width: 4),
              const Text('4.8', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadTripDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Voyage introuvable',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ce voyage n\'existe pas ou n\'est plus disponible.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editTrip();
        break;
      case 'share':
        _shareTrip();
        break;
      case 'delete':
        _deleteTrip();
        break;
    }
  }

  void _editTrip() {
    // TODO: Navigate to edit trip screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modification bientôt disponible')),
    );
  }

  void _shareTrip() {
    // TODO: Implement trip sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partage bientôt disponible')),
    );
  }

  void _deleteTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le voyage'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce voyage ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await AuthTokenService.instance.tripService.deleteTrip(widget.tripId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voyage supprimé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}