import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transport_models.dart';

class FlightInfoForm extends StatefulWidget {
  final FlightInfo? initialInfo;
  final Function(FlightInfo) onChanged;
  final bool enabled;

  const FlightInfoForm({
    super.key,
    this.initialInfo,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<FlightInfoForm> createState() => _FlightInfoFormState();
}

class _FlightInfoFormState extends State<FlightInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final _flightNumberController = TextEditingController();
  final _airlineController = TextEditingController();

  // Common airlines for autocomplete
  final List<String> _commonAirlines = [
    'Air Canada',
    'WestJet',
    'Porter Airlines',
    'Flair Airlines',
    'Air Transat',
    'Swoop',
    'American Airlines',
    'Delta Airlines',
    'United Airlines',
    'British Airways',
    'Lufthansa',
    'Air France',
    'KLM',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialInfo != null) {
      _flightNumberController.text = widget.initialInfo!.flightNumber;
      _airlineController.text = widget.initialInfo!.airline;
    }
    
    // Add listeners to notify parent of changes
    _flightNumberController.addListener(_notifyChanges);
    _airlineController.addListener(_notifyChanges);
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _airlineController.dispose();
    super.dispose();
  }

  void _notifyChanges() {
    if (_flightNumberController.text.isNotEmpty && 
        _airlineController.text.isNotEmpty) {
      final flightInfo = FlightInfo(
        flightNumber: _flightNumberController.text.trim().toUpperCase(),
        airline: _airlineController.text.trim(),
      );
      widget.onChanged(flightInfo);
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
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.flight,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations de vol',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Requis pour les voyages en avion',
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
            
            // Flight number
            TextFormField(
              controller: _flightNumberController,
              enabled: widget.enabled,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Numéro de vol *',
                hintText: 'Ex: AC123, WS456',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.airplane_ticket),
                helperText: 'Format: Code compagnie + numéro (ex: AC123)',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Numéro de vol requis';
                }
                if (!RegExp(r'^[A-Z]{1,3}[0-9]{1,4}$').hasMatch(value.trim())) {
                  return 'Format invalide (ex: AC123)';
                }
                return null;
              },
              onChanged: (value) {
                // Auto-format flight number
                final formatted = value.toUpperCase();
                if (formatted != value) {
                  _flightNumberController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Airline with autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _commonAirlines.where((airline) =>
                    airline.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _airlineController.text = selection;
                _notifyChanges();
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sync our controller with the autocomplete controller
                if (controller.text != _airlineController.text) {
                  controller.text = _airlineController.text;
                }
                
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: widget.enabled,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Compagnie aérienne *',
                    hintText: 'Ex: Air Canada',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_drop_down),
                      onPressed: () {
                        // Show all options when dropdown is pressed
                        focusNode.requestFocus();
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Compagnie aérienne requise';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _airlineController.text = value;
                    _notifyChanges();
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.business, size: 20),
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            // Info notes
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Informations importantes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Ces informations aideront à vérifier votre vol\n'
                    '• Assurez-vous que les détails correspondent à votre billet\n'
                    '• Vous pourrez modifier ces informations si nécessaire',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Weight reminder for flights
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.scale,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rappel : Limite de poids de 23 kg pour les vols',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[700],
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