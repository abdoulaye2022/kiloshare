import 'package:flutter/material.dart';
import '../services/logout_service.dart';

/// Widget de test pour vérifier le fonctionnement du service de déconnexion
/// À utiliser pendant le développement pour tester le nettoyage complet
class LogoutTestWidget extends StatelessWidget {
  const LogoutTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🧪 Test du Service de Déconnexion',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Bouton pour vérifier l'état avant nettoyage
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Vérifier État Actuel'),
            onPressed: () async {
              await LogoutService.debugVerifyCleanup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vérification terminée - Voir console'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
          
          const SizedBox(height: 8),
          
          // Bouton pour effectuer le nettoyage complet
          ElevatedButton.icon(
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Test Nettoyage Complet'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => _showLogoutTestDialog(context),
          ),
          
          const SizedBox(height: 8),
          
          // Bouton pour vérifier après nettoyage
          ElevatedButton.icon(
            icon: const Icon(Icons.verified),
            label: const Text('Vérifier Après Nettoyage'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await LogoutService.debugVerifyCleanup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vérification post-nettoyage terminée'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🧪 Test de Déconnexion'),
        content: const Text(
          'Ceci va effectuer un nettoyage complet de tous les états persistés '
          'sans vous déconnecter réellement (pour le test).\n\n'
          'Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              // Afficher un loader
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Test de nettoyage en cours...'),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              
              try {
                // Effectuer le nettoyage complet
                await LogoutService.performCompleteLogout();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Test de nettoyage réussi !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur lors du test: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Tester'),
          ),
        ],
      ),
    );
  }
}