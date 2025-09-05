import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trip_service.dart';
import '../services/multi_transport_service.dart';
import '../models/trip_model.dart';
import '../models/transport_models.dart';

class PriceCalculatorWidget extends StatefulWidget {
  final String? departureCity;
  final String? departureCountry;
  final String? arrivalCity;
  final String? arrivalCountry;
  final double weightKg;
  final TransportType? transportType;
  final Function(double pricePerKg, String currency) onPriceSelected;

  const PriceCalculatorWidget({
    super.key,
    this.departureCity,
    this.departureCountry,
    this.arrivalCity,
    this.arrivalCountry,
    required this.weightKg,
    this.transportType,
    required this.onPriceSelected,
  });

  @override
  State<PriceCalculatorWidget> createState() => _PriceCalculatorWidgetState();
}

class _PriceCalculatorWidgetState extends State<PriceCalculatorWidget> {
  final TripService _tripService = TripService();
  final MultiTransportService _multiTransportService = MultiTransportService();
  final TextEditingController _priceController = TextEditingController();

  PriceSuggestion? _priceSuggestion;
  MultiTransportPriceSuggestion? _multiTransportSuggestion;
  bool _isLoadingSuggestion = false;
  final String _selectedCurrency = 'CAD';
  double? _customPrice;
  bool _useSuggestedPrice = true;

  @override
  void initState() {
    super.initState();
    _loadPriceSuggestion();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PriceCalculatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.departureCity != widget.departureCity ||
        oldWidget.arrivalCity != widget.arrivalCity ||
        oldWidget.departureCountry != widget.departureCountry ||
        oldWidget.arrivalCountry != widget.arrivalCountry) {
      // Only reload if we have valid data
      if (widget.departureCity != null &&
          widget.departureCountry != null &&
          widget.arrivalCity != null &&
          widget.arrivalCountry != null) {
        _loadPriceSuggestion();
      }
    }
  }

  Future<void> _loadPriceSuggestion() async {
    print('=== DEBUG: _loadPriceSuggestion() START ===');
    print('DEBUG: departureCity: ${widget.departureCity}');
    print('DEBUG: departureCountry: ${widget.departureCountry}');
    print('DEBUG: arrivalCity: ${widget.arrivalCity}');
    print('DEBUG: arrivalCountry: ${widget.arrivalCountry}');
    print('DEBUG: weightKg: ${widget.weightKg}');
    print('DEBUG: transportType: ${widget.transportType}');

    // Safety check: ensure all required parameters are not null
    if (widget.departureCity == null ||
        widget.departureCountry == null ||
        widget.arrivalCity == null ||
        widget.arrivalCountry == null) {
      print('DEBUG: Missing required location data - setting default price');
      // Set default price if required data is missing
      final defaultPrice = 15.0; // CAD per kg
      _priceController.text = defaultPrice.toString();
      setState(() {
        _customPrice = defaultPrice;
        _useSuggestedPrice = false;
        _isLoadingSuggestion = false;
      });
      widget.onPriceSelected(defaultPrice, _selectedCurrency);
      return;
    }

    setState(() {
      _isLoadingSuggestion = true;
    });

    print('DEBUG: Starting price suggestion calculation...');

    try {
      // Always use fallback price suggestion since multi-transport API is not available
      print('DEBUG: Using fallback price suggestion service');
      await _useFallbackPriceSuggestion();
    } catch (e) {
      print('DEBUG: Final catch block - error: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (mounted) {
        // Set a default price when suggestion fails (no error toast)
        final defaultPrice = 15.0; // CAD per kg
        _priceController.text = defaultPrice.toString();
        setState(() {
          _customPrice = defaultPrice;
          _useSuggestedPrice = false;
        });
        widget.onPriceSelected(defaultPrice, _selectedCurrency);
      }
    } finally {
      setState(() {
        _isLoadingSuggestion = false;
      });
    }
  }

  void _onCustomPriceChanged(String value) {
    final price = double.tryParse(value);
    if (price != null && price > 0) {
      setState(() {
        _customPrice = price;
        _useSuggestedPrice = false;
      });
      widget.onPriceSelected(price, _selectedCurrency);
    }
  }

  void _selectSuggestedPrice() {
    final suggestedPrice = _getSuggestedPrice();
    if (suggestedPrice != null) {
      setState(() {
        _useSuggestedPrice = true;
        _priceController.clear();
        _customPrice = null;
      });
      widget.onPriceSelected(suggestedPrice, _selectedCurrency);
    }
  }

  double? _getSuggestedPrice() {
    if (_multiTransportSuggestion != null) {
      return _multiTransportSuggestion!.suggestedPricePerKg;
    } else if (_priceSuggestion != null) {
      return _priceSuggestion!.suggestedPricePerKg;
    }
    return null;
  }

  int? _getDistance() {
    if (_multiTransportSuggestion != null) {
      return _multiTransportSuggestion!.distanceKm;
    } else if (_priceSuggestion != null) {
      return _priceSuggestion!.distanceKm;
    }
    return null;
  }

  Future<void> _useFallbackPriceSuggestion() async {
    print('DEBUG: _useFallbackPriceSuggestion() START');
    print('DEBUG: Calling _tripService.getPriceSuggestion with:');
    print('DEBUG: - departureCity: ${widget.departureCity}');
    print('DEBUG: - departureCountry: ${widget.departureCountry}');
    print('DEBUG: - arrivalCity: ${widget.arrivalCity}');
    print('DEBUG: - arrivalCountry: ${widget.arrivalCountry}');
    print('DEBUG: - currency: $_selectedCurrency');

    final suggestion = await _tripService.getPriceSuggestion(
      departureCity: widget.departureCity!,
      departureCountry: widget.departureCountry!,
      arrivalCity: widget.arrivalCity!,
      arrivalCountry: widget.arrivalCountry!,
      currency: _selectedCurrency,
    );

    print('DEBUG: Received suggestion: $suggestion');
    print('DEBUG: Suggested price: ${suggestion.suggestedPricePerKg}');

    setState(() {
      _priceSuggestion = suggestion;
      _useSuggestedPrice = true;
    });

    // Auto-select the suggested price
    widget.onPriceSelected(suggestion.suggestedPricePerKg, _selectedCurrency);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Prix par kilogramme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Price suggestion
            if (_isLoadingSuggestion)
              _buildLoadingState()
            else if (_getSuggestedPrice() != null)
              _buildPriceSuggestion()
            else
              _buildManualPriceInput(),

            const SizedBox(height: 16),

            // Total earnings preview
            if (_getCurrentPrice() != null && widget.weightKg > 0)
              _buildEarningsPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Calcul du prix suggéré...'),
        ],
      ),
    );
  }

  Widget _buildPriceSuggestion() {
    return Column(
      children: [
        // Suggested price option
        InkWell(
          onTap: _selectSuggestedPrice,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _useSuggestedPrice
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              border: Border.all(
                color: _useSuggestedPrice
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _useSuggestedPrice,
                  onChanged: (value) => _selectSuggestedPrice(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Prix suggéré: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_getSuggestedPrice()!.toStringAsFixed(2)} $_selectedCurrency/kg',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Basé sur ${_getDistance()} km',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_useSuggestedPrice)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Custom price option
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: !_useSuggestedPrice
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: !_useSuggestedPrice
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Radio<bool>(
                value: false,
                groupValue: _useSuggestedPrice,
                onChanged: (value) {
                  setState(() {
                    _useSuggestedPrice = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Prix personnalisé',
                    suffixText: '$_selectedCurrency/kg',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: _onCustomPriceChanged,
                  onTap: () {
                    setState(() {
                      _useSuggestedPrice = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualPriceInput() {
    // Set a default value if the field is empty
    if (_priceController.text.isEmpty) {
      final defaultPrice = 15.0; // CAD per kg
      _priceController.text = defaultPrice.toString();
      _customPrice = defaultPrice;
      // Notify parent immediately with default price
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPriceSelected(defaultPrice, _selectedCurrency);
      });
    }

    return TextFormField(
      controller: _priceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: 'Prix par kilogramme',
        suffixText: '$_selectedCurrency/kg',
        border: const OutlineInputBorder(),
        helperText: 'Prix suggéré: 15 CAD/kg (modifiable)',
      ),
      onChanged: _onCustomPriceChanged,
    );
  }

  Widget _buildEarningsPreview() {
    final price = _getCurrentPriceWithFallback();
    final weightKg =
        widget.weightKg <= 0 ? 1.0 : widget.weightKg; // Avoid zero weight
    final totalEarnings = price * weightKg;
    final commission = totalEarnings * 0.15; // 15% commission
    final netEarnings = totalEarnings - commission;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.green[700]),
              const SizedBox(width: 8),
              const Text(
                'Aperçu des gains',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEarningsRow('Total client', totalEarnings, _selectedCurrency),
          _buildEarningsRow(
              'Commission KiloShare (15%)', commission, _selectedCurrency,
              isNegative: true),
          const Divider(),
          _buildEarningsRow('Vos gains nets', netEarnings, _selectedCurrency,
              isBold: true),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, double amount, String currency,
      {bool isNegative = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          '${isNegative ? '-' : ''}${amount.toStringAsFixed(2)} $currency',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
            color: isNegative
                ? Colors.red[600]
                : isBold
                    ? Colors.green[700]
                    : null,
          ),
        ),
      ],
    );
  }

  double? _getCurrentPrice() {
    if (_useSuggestedPrice) {
      return _getSuggestedPrice();
    } else if (!_useSuggestedPrice && _customPrice != null) {
      return _customPrice;
    }
    return null;
  }

  double _getCurrentPriceWithFallback() {
    final price = _getCurrentPrice();
    return price ?? 15.0; // Default fallback price
  }
}
