import 'package:flutter/material.dart';
import '../models/transport_models.dart';

class TransportTypeCard extends StatelessWidget {
  final TransportType transportType;
  final bool isSelected;
  final VoidCallback onTap;
  final double? weightLimit;
  final double? pricePerKg;

  const TransportTypeCard({
    super.key,
    required this.transportType,
    required this.isSelected,
    required this.onTap,
    this.weightLimit,
    this.pricePerKg,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                  ? _getTransportColor().withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                    ? _getTransportColor()
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: _getTransportColor().withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Transport icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getTransportColor().withOpacity(isSelected ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTransportIcon(),
                    size: 28,
                    color: _getTransportColor(),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Transport info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transportType.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected 
                              ? _getTransportColor()
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transportType.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (weightLimit != null) ...[
                            Icon(
                              Icons.scale,
                              size: 14,
                              color: _getTransportColor(),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${weightLimit!.toInt()} kg max',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _getTransportColor(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (pricePerKg != null) ...[
                            if (weightLimit != null) const SizedBox(width: 12),
                            Icon(
                              Icons.attach_money,
                              size: 14,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${pricePerKg!.toStringAsFixed(2)} CAD/kg',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? _getTransportColor()
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? _getTransportColor()
                          : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: Theme.of(context).colorScheme.surface,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTransportIcon() {
    switch (transportType) {
      case TransportType.flight:
      case TransportType.plane:
        return Icons.flight;
      case TransportType.car:
        return Icons.directions_car;
    }
  }

  Color _getTransportColor() {
    switch (transportType) {
      case TransportType.flight:
      case TransportType.plane:
        return Colors.blue[600]!;
      case TransportType.car:
        return Colors.green[600]!;
    }
  }
}