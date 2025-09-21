import 'package:flutter/material.dart';

class TripRulesSimpleConfirmationDialog extends StatefulWidget {
  final VoidCallback onConfirmed;

  const TripRulesSimpleConfirmationDialog({
    super.key,
    required this.onConfirmed,
  });

  @override
  State<TripRulesSimpleConfirmationDialog> createState() => _TripRulesSimpleConfirmationDialogState();
}

class _TripRulesSimpleConfirmationDialogState extends State<TripRulesSimpleConfirmationDialog> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).primaryColor,
              size: 48,
            ),
            const SizedBox(height: 16),

            Text(
              'Confirmation finale',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Êtes-vous prêt à publier votre annonce en respectant toutes les règles acceptées ?',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Case à cocher simple
            Row(
              children: [
                Checkbox(
                  value: _isAccepted,
                  onChanged: (value) {
                    setState(() {
                      _isAccepted = value ?? false;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
                Expanded(
                  child: Text(
                    'Je confirme respecter toutes les règles acceptées',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAccepted ? () {
                      Navigator.of(context).pop();
                      widget.onConfirmed();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Publier',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}