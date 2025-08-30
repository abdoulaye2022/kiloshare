import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_event.dart';
import '../../auth/services/auth_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _confirmDataDeletion = false;
  bool _confirmNoRecovery = false;
  bool _confirmCancelReservations = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer le compte'),
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWarningCard(),
              const SizedBox(height: 24),
              _buildConsequencesCard(),
              const SizedBox(height: 24),
              _buildConfirmationChecks(),
              const SizedBox(height: 24),
              _buildVerificationFields(),
              const SizedBox(height: 32),
              _buildDeleteButton(),
              const SizedBox(height: 16),
              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.red[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Suppression définitive du compte',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible. Une fois votre compte supprimé, '
              'il sera impossible de le récupérer.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsequencesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conséquences de la suppression',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildConsequenceItem(
              Icons.person_off,
              'Suppression du profil',
              'Toutes vos informations personnelles seront définitivement supprimées',
            ),
            _buildConsequenceItem(
              Icons.history,
              'Perte de l\'historique',
              'Tous vos voyages et réservations passés seront perdus',
            ),
            _buildConsequenceItem(
              Icons.cancel,
              'Annulation des réservations',
              'Toutes vos réservations actives seront automatiquement annulées',
            ),
            _buildConsequenceItem(
              Icons.star_border,
              'Perte des avis',
              'Tous les avis reçus et donnés seront supprimés',
            ),
            _buildConsequenceItem(
              Icons.account_balance_wallet,
              'Remboursements',
              'Les remboursements en cours seront traités selon nos conditions',
            ),
            _buildConsequenceItem(
              Icons.block,
              'Interdiction de recréation',
              'Vous ne pourrez pas recréer un compte avec la même adresse email pendant 6 mois',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsequenceItem(
      IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.red[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationChecks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmations requises',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                'Je comprends que toutes mes données seront supprimées',
                style: TextStyle(fontSize: 14),
              ),
              value: _confirmDataDeletion,
              onChanged: (value) {
                setState(() {
                  _confirmDataDeletion = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text(
                'Je comprends que cette action est irréversible',
                style: TextStyle(fontSize: 14),
              ),
              value: _confirmNoRecovery,
              onChanged: (value) {
                setState(() {
                  _confirmNoRecovery = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text(
                'Je comprends que mes réservations en cours seront annulées',
                style: TextStyle(fontSize: 14),
              ),
              value: _confirmCancelReservations,
              onChanged: (value) {
                setState(() {
                  _confirmCancelReservations = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vérification de sécurité',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Mot de passe
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Votre mot de passe',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre mot de passe';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Confirmation par texte
            TextFormField(
              controller: _confirmationController,
              decoration: const InputDecoration(
                labelText: 'Tapez "SUPPRIMER MON COMPTE" pour confirmer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.keyboard),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez confirmer en tapant le texte demandé';
                }
                if (value.toUpperCase() != 'SUPPRIMER MON COMPTE') {
                  return 'Le texte de confirmation ne correspond pas';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    final bool canDelete = _confirmDataDeletion &&
        _confirmNoRecovery &&
        _confirmCancelReservations;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading || !canDelete ? null : _deleteAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Suppression en cours...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever),
                  SizedBox(width: 8),
                  Text(
                    'SUPPRIMER DÉFINITIVEMENT MON COMPTE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: _isLoading ? null : () => context.pop(),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Annuler et conserver mon compte',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dernière confirmation
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Dernière confirmation',
          style: TextStyle(color: Colors.red[700]),
        ),
        content: const Text(
          'Êtes-vous absolument certain de vouloir supprimer définitivement votre compte ?\n\n'
          'Cette action est IRRÉVERSIBLE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non, annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.deleteAccount(
        password: _passwordController.text,
        confirmation: _confirmationController.text,
      );

      if (mounted) {
        // Déconnecter l'utilisateur
        context.read<AuthBloc>().add(AuthLogoutRequested());

        // Afficher le message de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre compte a été supprimé avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Rediriger vers la page de connexion
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la suppression du compte';

        if (e.toString().contains('401') ||
            e.toString().contains('wrong password')) {
          errorMessage = 'Mot de passe incorrect';
        } else if (e.toString().contains('pending_reservations')) {
          errorMessage =
              'Impossible de supprimer le compte avec des réservations en cours';
        } else if (e.toString().contains('network')) {
          errorMessage =
              'Erreur de connexion. Vérifiez votre connexion internet';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
