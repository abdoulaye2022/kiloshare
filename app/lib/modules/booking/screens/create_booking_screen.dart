import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/booking_service.dart';
import '../../trips/models/trip_model.dart';
import '../../../utils/toast_utils.dart';
import '../../../services/stripe_service.dart';

class CreateBookingScreen extends StatefulWidget {
  final Trip trip;

  const CreateBookingScreen({
    super.key,
    required this.trip,
  });

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookingService = BookingService.instance;
  final _stripeService = StripeService.instance;

  // Controllers pour les champs
  final _packageDescriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Écouter les changements de poids pour recalculer le prix
    _weightController.addListener(() {
      setState(() {}); // Redessiner l'interface pour mettre à jour le prix
    });
  }

  @override
  void dispose() {
    _packageDescriptionController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle réservation'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // En-tête avec informations du voyage
          _buildTripHeader(),
          // Formulaire de réservation
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Informations du colis'),
                    const SizedBox(height: 16),
                    _buildPackageDescriptionField(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildWeightField()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDimensionsField()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _buildPriceInfo(),
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle('Adresses (optionnel)'),
                    const SizedBox(height: 16),
                    _buildPickupAddressField(),
                    const SizedBox(height: 16),
                    _buildDeliveryAddressField(),
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle('Instructions spéciales'),
                    const SizedBox(height: 16),
                    _buildSpecialInstructionsField(),
                    const SizedBox(height: 32),
                    
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_takeoff, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                _formatDate(widget.trip.departureDate),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (widget.trip.pricePerKg > 0) ...[
                Icon(Icons.monetization_on, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${widget.trip.pricePerKg.toStringAsFixed(2)}\$/kg',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildPackageDescriptionField() {
    return TextFormField(
      controller: _packageDescriptionController,
      decoration: const InputDecoration(
        labelText: 'Description du colis *',
        hintText: 'Ex: Documents, vêtements, produits électroniques...',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.inventory_2),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Veuillez décrire le colis à transporter';
        }
        if (value.trim().length < 10) {
          return 'La description doit contenir au moins 10 caractères';
        }
        return null;
      },
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      decoration: const InputDecoration(
        labelText: 'Poids (kg) *',
        hintText: '0.0',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.scale),
        suffixText: 'kg',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Poids requis';
        }
        final weight = double.tryParse(value);
        if (weight == null || weight <= 0) {
          return 'Poids invalide';
        }
        if (weight > 100) {
          return 'Poids maximal: 100kg';
        }
        return null;
      },
    );
  }

  Widget _buildDimensionsField() {
    return TextFormField(
      controller: _dimensionsController,
      decoration: const InputDecoration(
        labelText: 'Dimensions (cm)',
        hintText: '30x20x10',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.straighten),
        suffixText: 'cm',
      ),
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          // Validation basique du format dimensions
          if (!RegExp(r'^\d+x\d+x\d+$').hasMatch(value.trim())) {
            return 'Format: LxlxH (ex: 30x20x10)';
          }
        }
        return null;
      },
    );
  }

  Widget _buildPriceInfo() {
    double weight = double.tryParse(_weightController.text) ?? 0.0;
    double totalPrice = weight * widget.trip.pricePerKg;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calcul du prix',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Prix par kg:', style: TextStyle(color: Colors.blue[700])),
              Text('${widget.trip.pricePerKg.toStringAsFixed(2)} ${widget.trip.currency}', 
                   style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700])),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Poids:', style: TextStyle(color: Colors.blue[700])),
              Text('${weight.toStringAsFixed(1)} kg', 
                   style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700])),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Prix total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
              Text('${totalPrice.toStringAsFixed(2)} ${widget.trip.currency}', 
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupAddressField() {
    return TextFormField(
      controller: _pickupAddressController,
      decoration: const InputDecoration(
        labelText: 'Adresse de collecte',
        hintText: 'Où récupérer le colis?',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
      maxLines: 2,
    );
  }

  Widget _buildDeliveryAddressField() {
    return TextFormField(
      controller: _deliveryAddressController,
      decoration: const InputDecoration(
        labelText: 'Adresse de livraison',
        hintText: 'Où livrer le colis?',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_off),
      ),
      maxLines: 2,
    );
  }

  Widget _buildSpecialInstructionsField() {
    return TextFormField(
      controller: _specialInstructionsController,
      decoration: const InputDecoration(
        labelText: 'Instructions spéciales',
        hintText: 'Informations importantes pour le transporteur...',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.note),
      ),
      maxLines: 3,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitBookingRequest,
        icon: _isLoading 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send),
        label: Text(_isLoading ? 'Envoi en cours...' : 'Envoyer la demande'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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

  /// Traiter le paiement immédiatement après la création de la réservation
  Future<bool> _processPayment({
    required String clientSecret,
    required double amount,
    required int bookingId,
  }) async {
    try {
      // Étape 1: Initialiser Stripe PaymentSheet
      final initResult = await _stripeService.initializePaymentSheet(
        clientSecret: clientSecret,
        amount: amount,
        currency: 'CAD',
        customerEmail: null, // Pourrait être récupéré du profil utilisateur
      );

      if (initResult['success'] != true) {
        if (mounted) {
          ToastUtils.showError(
            context,
            initResult['error'] ?? 'Erreur d\'initialisation du paiement',
          );
        }
        return false;
      }

      // Étape 2: Présenter la feuille de paiement à l'utilisateur
      final paymentResult = await _stripeService.presentPaymentSheet(
        clientSecret: clientSecret,
        paymentIntentId: '', // Pas nécessaire pour l'instant
      );

      if (paymentResult['success'] == true) {
        if (mounted) {
          ToastUtils.showSuccess(
            context,
            'Paiement autorisé avec succès! En attente de confirmation du transporteur.',
          );
        }
        return true;
      } else {
        // Paiement annulé ou échoué
        if (mounted) {
          ToastUtils.showError(
            context,
            paymentResult['error'] ?? 'Paiement annulé',
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(
          context,
          'Erreur lors du traitement du paiement: $e',
        );
      }
      return false;
    }
  }

  Future<void> _submitBookingRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validation supplémentaire avant parsing
      final weightText = _weightController.text.trim();
      if (weightText.isEmpty) {
        ToastUtils.showError(context, 'Le poids est requis');
        return;
      }

      final weight = double.tryParse(weightText);
      if (weight == null || weight <= 0) {
        ToastUtils.showError(context, 'Veuillez entrer un poids valide');
        return;
      }

      final result = await _bookingService.createBookingRequest(
        tripId: widget.trip.id.toString(),
        packageDescription: _packageDescriptionController.text.trim(),
        weight: weight,
        dimensionsCm: _dimensionsController.text.trim().isNotEmpty 
          ? _dimensionsController.text.trim() 
          : null,
        pickupAddress: _pickupAddressController.text.trim().isNotEmpty 
          ? _pickupAddressController.text.trim() 
          : null,
        deliveryAddress: _deliveryAddressController.text.trim().isNotEmpty 
          ? _deliveryAddressController.text.trim() 
          : null,
        pickupNotes: _specialInstructionsController.text.trim().isNotEmpty 
          ? _specialInstructionsController.text.trim() 
          : null,
      );

      if (result['success'] == true) {
        // Réservation créée avec succès
        final bookingData = result['booking'];
        final paymentData = result['payment'];

        if (mounted) {
          ToastUtils.showSuccess(
            context,
            result['message'] ?? 'Demande de réservation envoyée avec succès!',
          );
        }

        // Vérifier si un paiement est requis
        if (paymentData != null &&
            paymentData['client_secret'] != null &&
            paymentData['requires_payment_method'] == true) {

          // Traiter le paiement immédiatement
          final paymentSuccess = await _processPayment(
            clientSecret: paymentData['client_secret'],
            amount: double.tryParse(paymentData['amount']?.toString() ?? '0') ?? 0.0,
            bookingId: bookingData['id'],
          );

          if (paymentSuccess && mounted) {
            // Paiement réussi - retourner à l'écran précédent
            Navigator.of(context).pop(true);
          } else if (!paymentSuccess && mounted) {
            // Paiement échoué/annulé - informer l'utilisateur
            ToastUtils.showWarning(
              context,
              'Réservation créée mais paiement non effectué. Veuillez compléter le paiement depuis les détails de la réservation.',
            );
            Navigator.of(context).pop(true);
          }
        } else {
          // Pas de paiement requis (transporteur sans Stripe)
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        // Erreur
        if (mounted) {
          ToastUtils.showError(
            context,
            result['error'] ?? 'Erreur lors de l\'envoi de la demande',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(
          context,
          'Erreur inattendue: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}