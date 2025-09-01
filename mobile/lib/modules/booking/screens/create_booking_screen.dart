import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../../trips/models/trip_model.dart';

class CreateBookingScreen extends StatefulWidget {
  final Trip trip;

  const CreateBookingScreen({
    Key? key,
    required this.trip,
  }) : super(key: key);

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookingService = BookingService.instance;

  // Controllers pour les champs
  final _packageDescriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _proposedPriceController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir le prix par kg si disponible
    if (widget.trip.pricePerKg > 0) {
      _proposedPriceController.text = (widget.trip.pricePerKg * 5).toStringAsFixed(2); // Exemple pour 5kg
    }
  }

  @override
  void dispose() {
    _packageDescriptionController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _proposedPriceController.dispose();
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
                    
                    _buildSectionTitle('Prix et négociation'),
                    const SizedBox(height: 16),
                    _buildProposedPriceField(),
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

  Widget _buildProposedPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _proposedPriceController,
          decoration: InputDecoration(
            labelText: 'Prix proposé (CAD) *',
            hintText: '0.00',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
            suffixText: 'CAD',
            helperText: widget.trip.pricePerKg > 0 
              ? 'Prix du voyage: ${widget.trip.pricePerKg.toStringAsFixed(2)}\$/kg'
              : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Prix requis';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'Prix invalide';
            }
            if (price < 5) {
              return 'Prix minimum: 5\$ CAD';
            }
            if (price > 1000) {
              return 'Prix maximum: 1000\$ CAD';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Le transporteur peut négocier ce prix. Vous serez notifié de toute contre-proposition.',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Future<void> _submitBookingRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _bookingService.createBookingRequest(
        tripId: widget.trip.id.toString(),
        receiverId: widget.trip.userId.toString(),
        packageDescription: _packageDescriptionController.text.trim(),
        weightKg: double.parse(_weightController.text),
        proposedPrice: double.parse(_proposedPriceController.text),
        dimensionsCm: _dimensionsController.text.trim().isNotEmpty 
          ? _dimensionsController.text.trim() 
          : null,
        pickupAddress: _pickupAddressController.text.trim().isNotEmpty 
          ? _pickupAddressController.text.trim() 
          : null,
        deliveryAddress: _deliveryAddressController.text.trim().isNotEmpty 
          ? _deliveryAddressController.text.trim() 
          : null,
        specialInstructions: _specialInstructionsController.text.trim().isNotEmpty 
          ? _specialInstructionsController.text.trim() 
          : null,
      );

      if (result['success'] == true) {
        // Succès - retourner à l'écran précédent avec résultat
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Demande de réservation envoyée avec succès!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          Navigator.of(context).pop(true); // Indique le succès
        }
      } else {
        // Erreur
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Erreur lors de l\'envoi de la demande'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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