import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transport_models.dart';

class VehicleInfoForm extends StatefulWidget {
  final VehicleInfo? initialInfo;
  final Function(VehicleInfo) onChanged;
  final bool enabled;

  const VehicleInfoForm({
    super.key,
    this.initialInfo,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<VehicleInfoForm> createState() => _VehicleInfoFormState();
}

class _VehicleInfoFormState extends State<VehicleInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialInfo != null) {
      _makeController.text = widget.initialInfo!.make;
      _modelController.text = widget.initialInfo!.model;
      _licensePlateController.text = widget.initialInfo!.licensePlate;
      _yearController.text = widget.initialInfo!.year ?? '';
      _colorController.text = widget.initialInfo!.color ?? '';
    }
    
    // Add listeners to notify parent of changes
    _makeController.addListener(_notifyChanges);
    _modelController.addListener(_notifyChanges);
    _licensePlateController.addListener(_notifyChanges);
    _yearController.addListener(_notifyChanges);
    _colorController.addListener(_notifyChanges);
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _notifyChanges() {
    if (_makeController.text.isNotEmpty && 
        _modelController.text.isNotEmpty && 
        _licensePlateController.text.isNotEmpty) {
      final vehicleInfo = VehicleInfo(
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        licensePlate: _licensePlateController.text.trim().toUpperCase(),
        year: _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
        color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
      );
      widget.onChanged(vehicleInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: Colors.green[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations du véhicule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Requis pour les voyages en voiture',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Required fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _makeController,
                    enabled: widget.enabled,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Marque *',
                      hintText: 'Ex: Toyota',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.branding_watermark),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Marque requise';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    enabled: widget.enabled,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Modèle *',
                      hintText: 'Ex: Corolla',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.car_rental),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Modèle requis';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // License plate (required)
            TextFormField(
              controller: _licensePlateController,
              enabled: widget.enabled,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\s-]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Plaque d\'immatriculation *',
                hintText: 'Ex: ABC-123',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.confirmation_number),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Plaque d\'immatriculation requise';
                }
                if (value.trim().length < 3) {
                  return 'Format de plaque invalide';
                }
                return null;
              },
              onChanged: (value) {
                // Auto-format license plate
                final formatted = value.toUpperCase();
                if (formatted != value) {
                  _licensePlateController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Optional fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Année',
                      hintText: '2020',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final year = int.tryParse(value);
                        if (year == null) {
                          return 'Année invalide';
                        }
                        final currentYear = DateTime.now().year;
                        if (year < 1900 || year > currentYear + 1) {
                          return 'Année entre 1900 et ${currentYear + 1}';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _colorController,
                    enabled: widget.enabled,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Couleur',
                      hintText: 'Noir',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.palette),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ces informations aideront les expéditeurs à vous identifier lors du voyage',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
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

  bool validate() {
    return _formKey.currentState?.validate() ?? false;
  }
}