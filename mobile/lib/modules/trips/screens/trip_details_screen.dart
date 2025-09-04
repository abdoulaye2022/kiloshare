import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_token_service.dart';
import '../../../widgets/ellipsis_button.dart';
import '../models/trip_model.dart';
import '../models/trip_image_model.dart';
import '../widgets/trip_status_widget.dart';
import '../widgets/trip_actions_widget.dart';
import '../services/favorites_service.dart';
import '../../../widgets/optimized_cloudinary_image.dart';

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
  bool _isFavorite = false;
  bool _isOwner = false;

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
      final trip = await AuthTokenService.instance.tripService
          .getTripById(widget.tripId);

      // Vérifier le statut de favori en parallèle
      final isFavorite =
          await FavoritesService.instance.isFavorite(widget.tripId);

      setState(() {
        _trip = trip;
        _isFavorite = isFavorite;
        // For now, we'll consider all trips as owned by current user for actions
        // In a real app, you'd compare with the actual current user ID
        _isOwner = true; // TODO: Implement proper user ownership check
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
        actions: _trip != null
            ? [
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
                        title: Text('Supprimer',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ]
            : null,
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
          // Trip Images Gallery
          if (_trip!.hasImages) _buildImageGallery(),
          // Trip Status Widget
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TripStatusWidget(
              trip: _trip!,
              showDetails: true,
              showMetrics: true,
            ),
          ),
          const SizedBox(height: 16),
          // Trip Actions Widget (only for trip owner)
          if (_isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TripActionsWidget(
                trip: _trip!,
                onTripUpdated: (updatedTrip) => _handleTripUpdated(updatedTrip),
                onTripDeleted: () => _handleTripDeleted(),
              ),
            ),
          _buildActionButtons(),
          _buildTripInfo(),
          _buildPricingInfo(),
          _buildFlightInfo(),
          _buildRestrictionsInfo(),
          _buildContactInfo(),
          if (!_isOwner) _buildBookingSection(),
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
    String text;

    switch (status) {
      case TripStatus.draft:
        text = 'Brouillon';
        break;
      case TripStatus.pendingApproval:
        text = 'En attente d\'approbation';
        break;
      case TripStatus.active:
        text = 'Publié';
        break;
      case TripStatus.rejected:
        text = 'Rejeté';
        break;
      case TripStatus.pendingReview:
        text = 'Signalé pour révision';
        break;
      case TripStatus.booked:
        text = 'Réservé';
        break;
      case TripStatus.inProgress:
        text = 'En cours';
        break;
      case TripStatus.completed:
        text = 'Terminé';
        break;
      case TripStatus.cancelled:
        text = 'Annulé';
        break;
      case TripStatus.paused:
        text = 'En pause';
        break;
      case TripStatus.expired:
        text = 'Expiré';
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
                dateFormatter.format(trip.departureDate.toLocal()),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                timeFormatter.format(trip.departureDate.toLocal()),
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
              Icon(Icons.schedule,
                  size: 16, color: Colors.white.withOpacity(0.8)),
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
                dateFormatter.format(trip.arrivalDate.toLocal()),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                timeFormatter.format(trip.arrivalDate.toLocal()),
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
        _buildInfoRow('Poids disponible',
            '${trip.availableWeightKg.toStringAsFixed(1)} kg'),
        _buildInfoRow('Prix par kg',
            '${trip.pricePerKg.toStringAsFixed(2)} ${trip.currency}'),
        _buildInfoRow('Gain maximum',
            '${trip.totalEarningsPotential.toStringAsFixed(0)} ${trip.currency}'),
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

  Widget _buildActionButtons() {
    if (_trip == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Favorite button
          Expanded(
            child: EllipsisButton.outlined(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              text: _isFavorite ? 'Favoris ✓' : 'Favoris',
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Share button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareTrip,
              icon: const Icon(Icons.share),
              label: const Text('Partager'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          if (_isOwner) ...[
            const SizedBox(width: 12),

            // Edit button (owner only)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _editTrip,
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transporteur'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber[600]),
                  const SizedBox(width: 4),
                  const Text('4.8',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('(127 avis)', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          trailing: !_isOwner
              ? ElevatedButton(
                  onPressed: _contactTransporter,
                  child: const Text('Contacter'),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildBookingSection() {
    if (_trip == null || _isOwner) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.green[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.luggage, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Réserver cet espace',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Capacité disponible: ${_trip!.availableWeightKg.toStringAsFixed(1)} kg',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Prix: ${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency} par kg',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _trip!.status == TripStatus.active ? _bookTrip : null,
                  icon: const Icon(Icons.book_online),
                  label: const Text('Réserver maintenant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous pourrez préciser le poids exact et les détails lors de la réservation',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

  void _toggleFavorite() async {
    if (_trip == null) return;

    try {
      final result = await FavoritesService.instance.toggleFavorite(_trip!.id.toString());

      if (result['success'] == true) {
        setState(() {
          _isFavorite = result['isFavorite'] ?? false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris'),
              backgroundColor: _isFavorite ? Colors.green : Colors.grey[600],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la mise à jour des favoris'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour des favoris'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _contactTransporter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.message, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Contacter le transporteur',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Votre message',
                  hintText: 'Bonjour, je suis intéressé par votre voyage...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message envoyé au transporteur'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Envoyer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bookTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book_online, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Réserver cet espace',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Route: ${_trip!.routeDisplay}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Prix: ${_trip!.pricePerKg.toStringAsFixed(2)} ${_trip!.currency}/kg',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Poids à transporter (kg)',
                  hintText: '0.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Description du colis',
                  hintText:
                      'Décrivez brièvement ce que vous voulez transporter...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Demande de réservation envoyée'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTrip() {
    // TODO: Navigate to edit trip screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modification bientôt disponible')),
    );
  }

  void _shareTrip() {
    final trip = _trip!;
    final shareText = '''
🚀 Voyage disponible sur KiloShare

📍 ${trip.routeDisplay}
📅 ${trip.departureDate.day}/${trip.departureDate.month}/${trip.departureDate.year}
🧳 ${trip.availableWeightKg.toStringAsFixed(1)} kg disponibles
💰 ${trip.pricePerKg.toStringAsFixed(2)} ${trip.currency}/kg

Réservez maintenant: https://kiloshare.app/trips/${trip.id}
    ''';

    // In a real app, you would use the share plugin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lien copié dans le presse-papiers'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'VOIR',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Contenu à partager'),
                content: Text(shareText),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleTripUpdated(Trip updatedTrip) {
    setState(() {
      _trip = updatedTrip;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voyage mis à jour avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleTripDeleted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voyage supprimé avec succès'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back to trips list
    context.pop();
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
                await AuthTokenService.instance.tripService
                    .deleteTrip(widget.tripId);
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

  Widget _buildImageGallery() {
    final images = _trip!.images!;
    
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Photos du voyage (${images.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => _showImageViewer(images, index),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          OptimizedCloudinaryImage(
                            imageUrl: image.thumbnail ?? image.url,
                            imageType: 'trip_photo',
                            width: 160,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          if (image.isPrimary)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Principal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showImageViewer(List<TripImage> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                return InteractiveViewer(
                  child: OptimizedCloudinaryImage(
                    imageUrl: image.url,
                    imageType: 'trip_photo',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
