import 'package:flutter/material.dart';
import '../../../data/locations_data.dart';
import '../models/transport_models.dart';

class CityAutocompleteField extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? initialValue;
  final TransportType? transportType;
  final Function(String city, String country, String? code) onCitySelected;

  const CityAutocompleteField({
    super.key,
    required this.label,
    required this.icon,
    this.initialValue,
    this.transportType,
    required this.onCitySelected,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _suggestions = _getFilteredCities(query);
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getFilteredCities(String query) {
    if (widget.transportType == null) {
      // No transport type specified, return all cities
      return LocationsData.searchCities(query);
    }

    // Get all cities first
    final allCities = LocationsData.searchCities(query);

    // Filter based on transport type
    switch (widget.transportType!) {
      case TransportType.car:
        // Car: only Canadian cities
        return allCities.where((city) {
          return city['country'] == 'Canada';
        }).toList();

      case TransportType.flight:
      case TransportType.plane:
        // Flight: all cities (international allowed)
        return allCities;
    }
  }

  void _selectCity(Map<String, dynamic> city) {
    _controller.text = city['city'];
    setState(() {
      _suggestions = [];
    });

    widget.onCitySelected(
      city['city'],
      city['country'],
      city['code'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _onTextChanged,
          textCapitalization: TextCapitalization.words,
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final city = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_city,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    title: Text(
                      city['city'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            city['country'],
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (city['code'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              city['code'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () => _selectCity(city),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
