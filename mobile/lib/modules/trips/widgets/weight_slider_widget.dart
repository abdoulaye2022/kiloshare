import 'package:flutter/material.dart';

class WeightSliderWidget extends StatefulWidget {
  final double weight;
  final Function(double) onWeightChanged;
  final double minWeight;
  final double maxWeight;

  const WeightSliderWidget({
    super.key,
    required this.weight,
    required this.onWeightChanged,
    this.minWeight = 1.0,
    this.maxWeight = 23.0,
  });

  @override
  State<WeightSliderWidget> createState() => _WeightSliderWidgetState();
}

class _WeightSliderWidgetState extends State<WeightSliderWidget> {
  late double _currentWeight;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.weight.clamp(widget.minWeight, widget.maxWeight);
  }

  @override
  void didUpdateWidget(WeightSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weight != widget.weight) {
      _currentWeight = widget.weight.clamp(widget.minWeight, widget.maxWeight);
    }
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
                  Icons.luggage,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Poids disponible',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Weight display
            Center(
              child: Column(
                children: [
                  Text(
                    '${_currentWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getWeightDescription(_currentWeight),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                trackHeight: 6,
              ),
              child: Slider(
                value: _currentWeight,
                min: widget.minWeight,
                max: widget.maxWeight,
                divisions: ((widget.maxWeight - widget.minWeight) * 2).round(),
                onChanged: (value) {
                  setState(() {
                    _currentWeight = value;
                  });
                  widget.onWeightChanged(value);
                },
              ),
            ),
            
            // Min/Max labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.minWeight.toInt()} kg',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${widget.maxWeight.toInt()} kg',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Weight suggestions
            _buildWeightSuggestions(),
            
            const SizedBox(height: 16),
            
            // Info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Maximum autorisé en soute : 23 kg par bagage',
                      style: TextStyle(fontSize: 13),
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

  Widget _buildWeightSuggestions() {
    final suggestions = [
      {'weight': 5.0, 'label': '5 kg', 'description': 'Léger'},
      {'weight': 10.0, 'label': '10 kg', 'description': 'Moyen'},
      {'weight': 15.0, 'label': '15 kg', 'description': 'Standard'},
      {'weight': 20.0, 'label': '20 kg', 'description': 'Maximum'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggestions rapides',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: suggestions.map((suggestion) {
            final weight = suggestion['weight'] as double;
            final isSelected = (_currentWeight - weight).abs() < 0.1;
            
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentWeight = weight;
                    });
                    widget.onWeightChanged(weight);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          suggestion['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected 
                                ? Theme.of(context).primaryColor
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          suggestion['description'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected 
                                ? Theme.of(context).primaryColor
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getWeightDescription(double weight) {
    if (weight <= 5) return 'Idéal pour documents et objets légers';
    if (weight <= 10) return 'Parfait pour vêtements et accessoires';
    if (weight <= 15) return 'Bien pour électronique et cadeaux';
    if (weight <= 20) return 'Capacité généreuse pour divers objets';
    return 'Maximum autorisé en bagage soute';
  }
}