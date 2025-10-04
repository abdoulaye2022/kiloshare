import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class TripRulesConfirmationDialog extends StatefulWidget {
  final VoidCallback onConfirmed;

  const TripRulesConfirmationDialog({
    super.key,
    required this.onConfirmed,
  });

  @override
  State<TripRulesConfirmationDialog> createState() => _TripRulesConfirmationDialogState();
}

class _TripRulesConfirmationDialogState extends State<TripRulesConfirmationDialog> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Règles importantes',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Règle 1
              _buildRuleItem(
                context,
                Icons.schedule,
                'Sois sûre de tes dates et collecte les colis au moment que tu as indiqué.',
              ),

              const SizedBox(height: 16),

              // Règle 2
              _buildRuleItem(
                context,
                Icons.payment,
                'Aucune transaction en cash, les expéditeurs paient en ligne et tu es payé après le trajet.',
              ),

              const SizedBox(height: 16),

              // Règle 3
              _buildRuleItem(
                context,
                Icons.verified_user,
                'Vérifie bien le contenu des colis car tu es légalement responsable.',
              ),

              const SizedBox(height: 24),

              // Case à cocher avec texte de confirmation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'J\'accepte ces règles, la ',
                                  ),
                                  TextSpan(
                                    text: 'Politique d\'annulation des voyageurs',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // TODO: Ouvrir la politique d'annulation
                                        _showPolicyDialog(context, 'Politique d\'annulation des voyageurs');
                                      },
                                  ),
                                  const TextSpan(text: ', les '),
                                  TextSpan(
                                    text: 'conditions d\'utilisations',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // TODO: Ouvrir les conditions d'utilisation
                                        _showPolicyDialog(context, 'Conditions d\'utilisation');
                                      },
                                  ),
                                  const TextSpan(text: ' et la '),
                                  TextSpan(
                                    text: 'Politique de confidentialité',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // TODO: Ouvrir la politique de confidentialité
                                        _showPolicyDialog(context, 'Politique de confidentialité');
                                      },
                                  ),
                                  const TextSpan(
                                    text: '. Je comprends que mon compte pourrait être suspendu si ces règles ne sont pas respectées.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  void _showPolicyDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Cette section est en cours de développement. '
          'Les politiques et conditions seront bientôt disponibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}