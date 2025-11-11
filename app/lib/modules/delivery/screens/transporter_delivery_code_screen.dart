import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../booking/models/booking_model.dart';
import '../services/delivery_code_service.dart';

/// Écran pour le transporteur pour valider les codes de livraison
class TransporterDeliveryCodeScreen extends StatefulWidget {
  final List<BookingModel> bookings;

  const TransporterDeliveryCodeScreen({
    super.key,
    required this.bookings,
  });

  @override
  State<TransporterDeliveryCodeScreen> createState() =>
      _TransporterDeliveryCodeScreenState();
}

class _TransporterDeliveryCodeScreenState
    extends State<TransporterDeliveryCodeScreen> {
  final DeliveryCodeService _deliveryCodeService = DeliveryCodeService.instance;

  // Controllers pour les inputs de code
  final Map<int, TextEditingController> _codeControllers = {};
  final Map<int, bool> _validating = {}; // bookingId -> validating state
  final Map<int, bool> _validated = {}; // bookingId -> validated state

  @override
  void initState() {
    super.initState();
    // Créer un controller pour chaque réservation
    for (var booking in widget.bookings) {
      _codeControllers[booking.id] = TextEditingController();
      _validating[booking.id] = false;
      _validated[booking.id] = false;
    }
  }

  @override
  void dispose() {
    // Disposer tous les controllers
    for (var controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showContactOptions(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Contacter ${booking.senderName ?? 'le client'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.chat_bubble, color: Colors.blue[700]),
                ),
                title: const Text('Envoyer un message'),
                subtitle: const Text('Discutez via le chat'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to chat
                  context.push(
                    '/conversation?tripId=${booking.tripId}&tripOwnerId=${booking.senderId}&tripTitle=${Uri.encodeComponent(booking.packageDescription)}',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person, color: Colors.green[700]),
                ),
                title: const Text('Voir le profil'),
                subtitle: const Text('Avis, notes et informations'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to user's public profile
                  context.push(
                    '/users/${booking.senderId}/profile?userName=${Uri.encodeComponent(booking.senderName ?? 'Utilisateur')}',
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateCode(BookingModel booking) async {
    final code = _codeControllers[booking.id]?.text.trim();

    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer le code de livraison'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le code doit contenir 6 chiffres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _validating[booking.id] = true;
    });

    try {
      final result = await _deliveryCodeService.validateDeliveryCode(
        bookingId: booking.id.toString(),
        code: code,
      );

      setState(() {
        _validating[booking.id] = false;
      });

      if (result['success'] == true) {
        setState(() {
          _validated[booking.id] = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Code validé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          final attemptsRemaining = result['attempts_remaining'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result['error'] ?? 'Code invalide'}\n'
                  'Tentatives restantes: $attemptsRemaining'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _validating[booking.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Validation des livraisons'),
        elevation: 0,
      ),
      body: widget.bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune réservation à livrer',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.bookings.length,
              itemBuilder: (context, index) {
                final booking = widget.bookings[index];
                final isValidating = _validating[booking.id] ?? false;
                final isValidated = _validated[booking.id] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête avec info du colis
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.inventory_2,
                                  color: Colors.blue[700], size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking.packageDescription,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${booking.weightKg} kg',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isValidated)
                              IconButton(
                                onPressed: () => _showContactOptions(booking),
                                icon: const Icon(Icons.contact_phone),
                                color: Colors.blue[700],
                                tooltip: 'Contacter le client',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue[50],
                                  padding: const EdgeInsets.all(10),
                                ),
                              ),
                            if (isValidated)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Livré',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Divider(height: 1, color: Colors.grey[200]),
                        const SizedBox(height: 16),

                        // Instructions ou confirmation
                        if (!isValidated) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Demandez le code à 6 chiffres au client',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Input du code
                          TextField(
                            controller: _codeControllers[booking.id],
                            enabled: !isValidating,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Code de livraison',
                              hintText: '000000',
                              prefixIcon: const Icon(Icons.pin),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Bouton de validation
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isValidating
                                  ? null
                                  : () => _validateCode(booking),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: isValidating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Confirmer la livraison',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          // Message de confirmation
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green[700], size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Livraison confirmée avec succès',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
