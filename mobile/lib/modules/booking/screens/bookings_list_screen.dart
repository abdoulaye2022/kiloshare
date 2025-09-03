import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../../auth/services/auth_service.dart';
import '../../../services/stripe_service.dart';

class BookingsListScreen extends StatefulWidget {
  const BookingsListScreen({super.key});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService.instance;
  final AuthService _authService = AuthService.instance;
  final StripeService _stripeService = StripeService.instance;
  
  late TabController _tabController;
  List<BookingModel> _sentBookings = [];
  List<BookingModel> _receivedBookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    
    // Vérifier si l'utilisateur est connecté
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sentBookings = [];
          _receivedBookings = [];
          _error = null;
        });
      }
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Charger les réservations envoyées
      final sentResult = await _bookingService.getUserBookings(role: 'sender');
      if (sentResult['success'] == true) {
        _sentBookings = (sentResult['bookings'] as List)
            .map((json) => BookingModel.fromJson(json))
            .toList();
      }

      // Charger les réservations reçues
      final receivedResult = await _bookingService.getUserBookings(role: 'receiver');
      if (receivedResult['success'] == true) {
        _receivedBookings = (receivedResult['bookings'] as List)
            .map((json) => BookingModel.fromJson(json))
            .toList();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement des réservations: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(
              icon: Icon(Icons.send),
              text: 'Envoyées',
            ),
            Tab(
              icon: Icon(Icons.inbox),
              text: 'Reçues',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingWidget()
          : _error != null 
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsList(_sentBookings, 'sender'),
                    _buildBookingsList(_receivedBookings, 'receiver'),
                  ],
                ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Chargement des réservations...'),
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
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, String userRole) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              userRole == 'sender' ? Icons.send_outlined : Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              userRole == 'sender' 
                  ? 'Aucune réservation envoyée'
                  : 'Aucune réservation reçue',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userRole == 'sender'
                  ? 'Vos demandes de transport apparaîtront ici'
                  : 'Les demandes de transport pour vos voyages apparaîtront ici',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildBookingCard(booking, userRole);
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking, String userRole) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBookingDetails(booking, userRole),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec route et statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.routeDescription,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (booking.tripDepartureDate != null)
                          Text(
                            _formatDate(booking.tripDepartureDate!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(booking.status),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Informations du colis
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colis: ${booking.packageDescription}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.scale, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${booking.weightKg} kg',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.attach_money, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${booking.effectivePrice.toStringAsFixed(2)} CAD',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Informations utilisateur
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      userRole == 'sender' 
                          ? (booking.receiverName?.substring(0, 1).toUpperCase() ?? 'R')
                          : (booking.senderName?.substring(0, 1).toUpperCase() ?? 'S'),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userRole == 'sender' 
                              ? 'Transporteur: ${booking.receiverName ?? 'Non spécifié'}'
                              : 'Expéditeur: ${booking.senderName ?? 'Non spécifié'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          userRole == 'sender' 
                              ? (booking.receiverEmail ?? '')
                              : (booking.senderEmail ?? ''),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Actions rapides pour les réservations reçues en attente
              if (userRole == 'receiver' && booking.isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectBooking(booking),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Refuser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptBooking(booking),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accepter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BookingStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.value,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(BookingModel booking, String userRole) {
    context.push('/bookings/${booking.id}');
  }

  Future<void> _acceptBooking(BookingModel booking) async {
    // D'abord, vérifier le statut Stripe
    final stripeStatus = await _stripeService.getAccountStatus();
    
    if (stripeStatus['success'] != true) {
      _showStripeErrorDialog('Impossible de vérifier votre compte Stripe. Veuillez réessayer.');
      return;
    }
    
    final canAcceptBookings = stripeStatus['transaction_ready'] == true;
    
    if (!canAcceptBookings) {
      _showStripeSetupDialog(stripeStatus);
      return;
    }

    // Si Stripe est configuré, procéder normalement
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AcceptBookingDialog(booking: booking),
    );

    if (result != null && result['confirmed'] == true) {
      if (!mounted) return;
      
      // Afficher loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final acceptResult = await _bookingService.acceptBooking(
          booking.id.toString(),
          finalPrice: result['finalPrice'],
        );

        if (mounted) {
          Navigator.of(context).pop(); // Fermer loader

          if (acceptResult['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Réservation acceptée avec succès!'),
                backgroundColor: Colors.green,
              ),
            );
            _loadBookings(); // Recharger la liste
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(acceptResult['error'] ?? 'Erreur lors de l\'acceptation'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Fermer loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la réservation'),
        content: Text(
          'Êtes-vous sûr de vouloir refuser cette réservation?\n\n'
          'Colis: ${booking.packageDescription}\n'
          'Poids: ${booking.weightKg} kg\n'
          'Prix proposé: ${booking.proposedPrice.toStringAsFixed(2)} CAD'
        ),
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
      if (!mounted) return;
      
      // Afficher loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final rejectResult = await _bookingService.rejectBooking(booking.id.toString());

        if (mounted) {
          Navigator.of(context).pop(); // Fermer loader

          if (rejectResult['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Réservation refusée'),
                backgroundColor: Colors.orange,
              ),
            );
            _loadBookings(); // Recharger la liste
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(rejectResult['error'] ?? 'Erreur lors du refus'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Fermer loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showStripeErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur Stripe'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStripeSetupDialog(Map<String, dynamic> stripeStatus) {
    final hasAccount = stripeStatus['has_account'] == true;
    final onboardingComplete = stripeStatus['onboarding_complete'] == true;

    String title;
    String content;
    String actionText;

    if (!hasAccount) {
      title = 'Compte Stripe requis';
      content = 'Pour accepter des réservations et recevoir des paiements, vous devez configurer votre compte Stripe Connect.\n\nCela vous permet de recevoir vos gains directement sur votre compte bancaire.';
      actionText = 'Configurer maintenant';
    } else if (!onboardingComplete) {
      title = 'Configuration Stripe incomplète';
      content = 'Votre compte Stripe Connect n\'est pas entièrement configuré. Terminez la configuration pour pouvoir accepter des réservations.\n\nIl vous manque peut-être des informations personnelles ou bancaires.';
      actionText = 'Terminer la configuration';
    } else {
      title = 'Compte Stripe en attente';
      content = 'Votre compte Stripe Connect est en cours de vérification. Cette étape peut prendre quelques minutes à quelques jours.\n\nVous pourrez accepter des réservations une fois la vérification terminée.';
      actionText = 'Vérifier le statut';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La configuration prend seulement quelques minutes et est sécurisée par Stripe.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/profile/wallet');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Dialog pour accepter une réservation avec possibilité de négocier le prix
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
      content: Column(
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
            ),
          ],
        ],
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