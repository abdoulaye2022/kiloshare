import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../../auth/services/auth_service.dart';
import '../../../services/stripe_service.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final BookingService _bookingService = BookingService.instance;
  final AuthService _authService = AuthService.instance;
  
  BookingModel? _booking;
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadBookingDetails();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user.id;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'utilisateur: $e');
    }
  }

  Future<void> _loadBookingDetails() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _bookingService.getBooking(widget.bookingId);
      print('BookingDetailsScreen received result: $result');
      
      if (result['success'] == true) {
        final bookingData = result['booking'];
        if (bookingData != null && bookingData is Map<String, dynamic>) {
          setState(() {
            _booking = BookingModel.fromJson(bookingData);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Données de réservation invalides ou manquantes';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Erreur lors du chargement de la réservation';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Réservation #${widget.bookingId}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_booking != null)
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (context) => [
                if (_booking!.isPending) ...[
                  if (_isReceiver) ...[
                    const PopupMenuItem(
                      value: 'accept',
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text('Accepter'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reject',
                      child: ListTile(
                        leading: Icon(Icons.cancel, color: Colors.red),
                        title: Text('Refuser'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
                if (_booking!.isAccepted && _isReceiver)
                  const PopupMenuItem(
                    value: 'payment-ready',
                    child: ListTile(
                      leading: Icon(Icons.payment),
                      title: Text('Marquer prêt pour paiement'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (_booking!.isAccepted && _isSender)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                      leading: Icon(Icons.cancel, color: Colors.red),
                      title: Text('Annuler la réservation'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Actualiser'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingWidget()
          : _error != null 
              ? _buildErrorWidget()
              : _booking != null
                  ? _buildBookingDetails()
                  : _buildNotFoundWidget(),
    );
  }

  Widget _buildLoadingWidget() {
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

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Une erreur inconnue s\'est produite',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBookingDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Réservation introuvable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Cette réservation n\'existe pas ou a été supprimée.'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSection(),
          const SizedBox(height: 24),
          _buildTripInfoSection(),
          const SizedBox(height: 24),
          _buildPackageInfoSection(),
          const SizedBox(height: 24),
          _buildPriceSection(),
          const SizedBox(height: 24),
          _buildParticipantsSection(),
          const SizedBox(height: 24),
          _buildAddressesSection(),
          if (_booking!.specialInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            _buildInstructionsSection(),
          ],
          const SizedBox(height: 24),
          _buildTimestampSection(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Statut de la réservation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: _buildLargeStatusChip(_booking!.status),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getStatusDescription(_booking!.status),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight_takeoff, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Informations du voyage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Route', _booking!.routeDescription),
            if (_booking!.tripDepartureDate != null)
              _buildInfoRow('Date de départ', _formatDate(_booking!.tripDepartureDate!)),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'Détails du colis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Description', _booking!.packageDescription),
            _buildInfoRow('Poids', '${_booking!.weightKg} kg'),
            if (_booking!.dimensionsCm?.isNotEmpty == true)
              _buildInfoRow('Dimensions', '${_booking!.dimensionsCm} cm'),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Informations financières',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Prix proposé', 
              '${_booking!.proposedPrice.toStringAsFixed(2)} CAD'
            ),
            if (_booking!.finalPrice != null && _booking!.finalPrice != _booking!.proposedPrice)
              _buildInfoRow(
                'Prix final négocié', 
                '${_booking!.finalPrice!.toStringAsFixed(2)} CAD'
              ),
            _buildInfoRow(
              'Prix effectif', 
              '${_booking!.effectivePrice.toStringAsFixed(2)} CAD',
              valueStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                Text(
                  'Participants',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Expéditeur
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.send, color: Colors.blue.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expéditeur',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              _booking!.senderName ?? 'Non spécifié',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_booking!.senderEmail?.isNotEmpty == true)
                              Text(
                                _booking!.senderEmail!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Transporteur
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.green.shade100,
                        child: Icon(Icons.local_shipping, color: Colors.green.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transporteur',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              _booking!.receiverName ?? 'Non spécifié',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_booking!.receiverEmail?.isNotEmpty == true)
                              Text(
                                _booking!.receiverEmail!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesSection() {
    if (_booking!.pickupAddress?.isEmpty == true && _booking!.deliveryAddress?.isEmpty == true) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  'Adresses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_booking!.pickupAddress?.isNotEmpty == true)
              _buildInfoRow('Collecte', _booking!.pickupAddress!),
            if (_booking!.deliveryAddress?.isNotEmpty == true)
              _buildInfoRow('Livraison', _booking!.deliveryAddress!),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Instructions spéciales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                _booking!.specialInstructions!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Historique',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Créée le', _formatDateTime(_booking!.createdAt)),
            _buildInfoRow('Mise à jour', _formatDateTime(_booking!.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Boutons pour réservations en attente (voyageur)
    if (_booking!.isPending && _isReceiver) {
      return _buildPendingReceiverActions();
    }

    // Actions pour l'expéditeur selon le statut
    if (_isSender) {
      if (_booking!.isAccepted) {
        return _buildPaymentActions();
      } else if (_booking!.isPaymentAuthorized) {
        return _buildPaymentConfirmationActions();
      } else if (_booking!.isPaymentConfirmed) {
        return _buildPaymentConfirmedInfo();
      }
    }

    // Actions pour le transporteur selon le statut
    if (_isReceiver) {
      if (_booking!.status == BookingStatus.paymentConfirmed) {
        return _buildCapturePaymentActions(); // Affiche le message informatif
      }
    }

    // Bouton d'annulation pour les statuts appropriés
    if (_booking!.canCancelBeforePayment && _isSender) {
      return _buildCancellationActions();
    }

    return const SizedBox.shrink();
  }
  
  Widget _buildPendingReceiverActions() {

    return Column(
      children: [
        if (_isReceiver) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _acceptBooking(),
              icon: const Icon(Icons.check_circle),
              label: const Text('Accepter la réservation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectBooking(),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
        ],
      ],
    );
  }

  Widget _buildPaymentActions() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.payment, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Réservation acceptée !',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Procédez au paiement pour confirmer votre réservation',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Montant à payer',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${_booking!.finalPrice?.toStringAsFixed(2) ?? _booking!.proposedPrice.toStringAsFixed(2)} CAD',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Commission: 15%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmPayment(),
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmer le paiement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _cancelBooking(),
            icon: const Icon(Icons.cancel),
            label: const Text('Annuler la réservation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Actions pour confirmer le paiement (expéditeur, après acceptation)
  Widget _buildPaymentConfirmationActions() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirmation de paiement requise',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vous avez 4 heures pour confirmer ce paiement, sinon il sera automatiquement annulé.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmPayment(),
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmer le paiement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _cancelBooking(),
            icon: const Icon(Icons.cancel),
            label: const Text('Annuler maintenant (gratuit)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Informations pour paiement confirmé (expéditeur)
  Widget _buildPaymentConfirmedInfo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paiement autorisé',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Les fonds sont réservés sur votre carte mais pas encore débités. Le montant sera prélevé automatiquement 72h avant le départ ou à la collecte du colis.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Bouton d'annulation (libération des fonds)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _cancelBooking(),
            icon: const Icon(Icons.cancel),
            label: const Text('Annuler la réservation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orange.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Actions pour capturer le paiement (transporteur)
  Widget _buildCapturePaymentActions() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paiement prêt à être capturé',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Le paiement sera automatiquement capturé lors de la validation du code secret de livraison.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pour recevoir le paiement, utilisez le code secret lors de la livraison du colis.',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Actions d'annulation simple
  Widget _buildCancellationActions() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _cancelBooking(),
        icon: const Icon(Icons.cancel),
        label: const Text('Annuler la réservation'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.shade300),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ?? Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStatusChip(BookingStatus status) {
    Color backgroundColor;
    Color textColor;
    IconData iconData;

    switch (status) {
      case BookingStatus.pending:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        iconData = Icons.hourglass_empty;
        break;
      case BookingStatus.accepted:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        iconData = Icons.check_circle;
        break;
      case BookingStatus.rejected:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        iconData = Icons.cancel;
        break;
      case BookingStatus.paymentPending:
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade700;
        iconData = Icons.payment;
        break;
      case BookingStatus.paid:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        iconData = Icons.paid;
        break;
      case BookingStatus.completed:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        iconData = Icons.check_circle_outline;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        iconData = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 20, color: textColor),
          const SizedBox(width: 8),
          Text(
            _booking!.statusDisplayText,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isReceiver {
    if (_currentUserId == null || _booking == null) return false;
    return _currentUserId.toString() == _booking!.receiverId;
  }
  
  bool get _isSender {
    if (_currentUserId == null || _booking == null) return false;
    return _currentUserId.toString() == _booking!.senderId;
  }

  Future<void> _cancelBooking() async {
    // Déterminer le message selon le statut du paiement
    String dialogContent;
    if (_booking!.isPaymentConfirmed) {
      // Paiement confirmé mais pas encore capturé = argent pas encore débité
      dialogContent = 'Êtes-vous sûr de vouloir annuler cette réservation?\n\n'
          '💳 L\'autorisation de paiement sera annulée et les fonds réservés sur votre carte seront libérés immédiatement.\n\n'
          '✅ Aucun montant ne sera débité de votre carte.\n\n'
          'L\'annulation est gratuite jusqu\'à 72h avant le départ.';
    } else if (_booking!.status == BookingStatus.paid) {
      // Paiement capturé = argent débité, remboursement nécessaire
      dialogContent = 'Êtes-vous sûr de vouloir annuler cette réservation?\n\n'
          '💰 Un remboursement sera automatiquement traité dans un délai de 3-5 jours ouvrables.\n\n'
          'Des frais d\'annulation peuvent s\'appliquer selon les conditions.';
    } else {
      // Pas encore de paiement
      dialogContent = 'Êtes-vous sûr de vouloir annuler cette réservation?\n\n'
          'L\'annulation est gratuite à ce stade.';
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre de handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Titre
              Text(
                'Annuler la réservation',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Contenu
              Text(
                dialogContent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text('Retour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Confirmer l\'annulation'),
                    ),
                  ),
                ],
              ),
              // Espace pour gérer le clavier/bottom safe area
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      _showLoader();

      try {
        final cancelResult = await _bookingService.cancelBooking(_booking!.id.toString());

        _hideLoader();

        if (cancelResult['success'] == true) {
          _showSuccessSnackBar('Réservation annulée avec succès');
          _loadBookingDetails();
        } else {
          _showErrorSnackBar(cancelResult['error'] ?? 'Erreur lors de l\'annulation');
        }
      } catch (e) {
        _hideLoader();
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  String _getStatusDescription(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return _isReceiver 
            ? 'Cette réservation attend votre approbation'
            : 'Votre demande attend une réponse du transporteur';
      case BookingStatus.accepted:
        return 'La réservation a été acceptée et attend le paiement';
      case BookingStatus.rejected:
        return 'Cette réservation a été refusée';
      case BookingStatus.paymentPending:
        return 'Le paiement est requis pour finaliser la réservation';
      case BookingStatus.paid:
        return 'Le paiement a été effectué avec succès';
      case BookingStatus.completed:
        return 'La livraison a été effectuée et confirmée';
      default:
        return 'Statut de la réservation';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'accept':
        _acceptBooking();
        break;
      case 'reject':
        _rejectBooking();
        break;
      case 'payment-ready':
        _markPaymentReady();
        break;
      case 'cancel':
        _cancelBooking();
        break;
      case 'refresh':
        _loadBookingDetails();
        break;
    }
  }

  Future<void> _acceptBooking() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AcceptBookingDialog(booking: _booking!),
    );

    if (result != null && result['confirmed'] == true) {
      _showLoader();

      try {
        final acceptResult = await _bookingService.acceptBooking(
          _booking!.id.toString(),
          finalPrice: result['finalPrice'],
        );

        _hideLoader();

        if (acceptResult['success'] == true) {
          _showSuccessSnackBar('Réservation acceptée avec succès!');
          _loadBookingDetails();
        } else {
          _showErrorSnackBar(acceptResult['error'] ?? 'Erreur lors de l\'acceptation');
        }
      } catch (e) {
        _hideLoader();
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  Future<void> _rejectBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la réservation'),
        content: const Text('Êtes-vous sûr de vouloir refuser cette réservation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoader();

      try {
        final rejectResult = await _bookingService.rejectBooking(_booking!.id.toString());

        _hideLoader();

        if (rejectResult['success'] == true) {
          _showSuccessSnackBar('Réservation refusée');
          _loadBookingDetails();
        } else {
          _showErrorSnackBar(rejectResult['error'] ?? 'Erreur lors du refus');
        }
      } catch (e) {
        _hideLoader();
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }



  Future<void> _markPaymentReady() async {
    _showLoader();

    try {
      final result = await _bookingService.markPaymentReady(_booking!.id.toString());

      _hideLoader();

      if (result['success'] == true) {
        _showSuccessSnackBar('Réservation marquée comme prête pour le paiement');
        _loadBookingDetails();
      } else {
        _showErrorSnackBar(result['error'] ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      _hideLoader();
      _showErrorSnackBar('Erreur: $e');
    }
  }

  void _showLoader() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoader() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed, // Collé au bottom de la page
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars pour éviter les doublons
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed, // Collé au bottom de la page
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Confirmer le paiement avec Stripe PaymentSheet
  Future<void> _confirmPayment() async {
    try {
      // Étape 1: Vérifier que nous avons une réservation
      if (_booking == null) {
        await _loadBookingDetails();
        if (_booking == null) {
          _showErrorSnackBar('Impossible de charger les détails de la réservation');
          return;
        }
      }

      // Étape 2: Obtenir le client_secret via l'API (cela vérifie aussi la présence d'une autorisation)
      final paymentDetails = await _bookingService.getPaymentDetails(widget.bookingId);
      if (paymentDetails['success'] != true) {
        _showErrorSnackBar(paymentDetails['error'] ?? 'Impossible d\'obtenir les détails de paiement');
        return;
      }

      if (paymentDetails['client_secret'] == null) {
        _showErrorSnackBar('Aucune autorisation de paiement trouvée pour cette réservation');
        return;
      }

      // Étape 3: Initialiser et présenter Stripe PaymentSheet
      final stripeService = StripeService.instance;

      // Initialiser la feuille de paiement
      final initResult = await stripeService.initializePaymentSheet(
        clientSecret: paymentDetails['client_secret'],
        amount: _booking!.finalPrice?.toDouble() ?? _booking!.proposedPrice,
        currency: 'CAD',
        customerEmail: null, // Pourrait être récupéré du profil utilisateur
      );

      if (initResult['success'] != true) {
        _showErrorSnackBar(initResult['error'] ?? 'Erreur d\'initialisation du paiement');
        return;
      }

      // Présenter la feuille de paiement
      final paymentResult = await stripeService.presentPaymentSheet(
        clientSecret: paymentDetails['client_secret'],
        paymentIntentId: paymentDetails['payment_intent_id'] ?? '',
      );

      if (paymentResult['success'] == true) {
        // Étape 4: Confirmer côté serveur que le paiement a été traité
        final confirmResult = await _bookingService.confirmPayment(widget.bookingId);

        if (confirmResult['success'] == true) {
          _showSuccessSnackBar(confirmResult['message'] ?? 'Paiement confirmé avec succès');
          _loadBookingDetails(); // Recharger les détails
        } else {
          _showErrorSnackBar(confirmResult['error'] ?? 'Erreur lors de la confirmation serveur');
        }
      } else {
        // Paiement annulé ou échoué
        _showErrorSnackBar(paymentResult['error'] ?? 'Paiement annulé');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur de connexion: $e');
    }
  }

}

// Dialog pour accepter une réservation
class _AcceptBookingDialog extends StatefulWidget {
  final BookingModel booking;

  const _AcceptBookingDialog({required this.booking});

  @override
  State<_AcceptBookingDialog> createState() => _AcceptBookingDialogState();
}

class _AcceptBookingDialogState extends State<_AcceptBookingDialog> {
  final _priceController = TextEditingController();
  bool _useOriginalPrice = true;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.booking.proposedPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accepter la réservation'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Colis: ${widget.booking.packageDescription}'),
              Text('Poids: ${widget.booking.weightKg} kg'),
              const SizedBox(height: 16),
              
              Text(
                'Prix proposé: ${widget.booking.proposedPrice.toStringAsFixed(2)} CAD',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 16),
              
              CheckboxListTile(
                title: const Text('Accepter le prix proposé'),
                value: _useOriginalPrice,
                onChanged: (value) {
                  setState(() {
                    _useOriginalPrice = value ?? true;
                    if (_useOriginalPrice) {
                      _priceController.text = widget.booking.proposedPrice.toStringAsFixed(2);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              
              if (!_useOriginalPrice) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Votre prix (CAD)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final finalPrice = _useOriginalPrice 
                ? null 
                : double.tryParse(_priceController.text);
                
            if (!_useOriginalPrice && (finalPrice == null || finalPrice <= 0)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez entrer un prix valide'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(bottom: 20, left: 16, right: 16),
                ),
              );
              return;
            }
            
            Navigator.of(context).pop({
              'confirmed': true,
              'finalPrice': finalPrice,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Accepter'),
        ),
      ],
    );
  }
}


