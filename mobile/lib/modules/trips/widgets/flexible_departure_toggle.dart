import 'package:flutter/material.dart';

class FlexibleDepartureToggle extends StatefulWidget {
  final bool initialValue;
  final Function(bool) onChanged;
  final bool enabled;

  const FlexibleDepartureToggle({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<FlexibleDepartureToggle> createState() => _FlexibleDepartureToggleState();
}

class _FlexibleDepartureToggleState extends State<FlexibleDepartureToggle> 
    with SingleTickerProviderStateMixin {
  late bool _isEnabled;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialValue;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (_isEnabled) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FlexibleDepartureToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _isEnabled = widget.initialValue;
      });
      if (_isEnabled) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _toggleValue() {
    if (!widget.enabled) return;
    
    setState(() {
      _isEnabled = !_isEnabled;
    });
    
    if (_isEnabled) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    widget.onChanged(_isEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: _isEnabled 
                  ? Colors.green[50]
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEnabled 
                    ? Colors.green[300]!
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: _isEnabled ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.enabled ? _toggleValue : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isEnabled 
                                  ? Colors.green[100]
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isEnabled ? Icons.schedule : Icons.access_time,
                              color: _isEnabled 
                                  ? Colors.green[700]
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Départ flexible',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _isEnabled 
                                        ? Colors.green[700]
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isEnabled 
                                      ? 'Horaire de départ ajustable selon les besoins'
                                      : 'Horaire de départ fixe',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Switch(
                              key: ValueKey(_isEnabled),
                              value: _isEnabled,
                              onChanged: widget.enabled ? (value) => _toggleValue() : null,
                              activeColor: Colors.green[600],
                              activeTrackColor: Colors.green[200],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_isEnabled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vous pourrez ajuster l\'heure de départ selon les demandes des expéditeurs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
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
              ),
            ),
          ),
        );
      },
    );
  }
}