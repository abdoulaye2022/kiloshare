import 'package:flutter/material.dart';
import '../../auth/services/social_auth_service.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  // État des comptes liés (en réalité, ces données viendraient de l'API)
  bool _googleLinked = false;
  bool _appleLinked = true;
  bool _facebookLinked = false;

  String? _googleEmail;
  String? _appleEmail;
  String? _facebookEmail;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedAccounts();
  }

  Future<void> _loadLinkedAccounts() async {
    // TODO: Charger les comptes liés depuis l'API
    setState(() {
      _googleLinked = false;
      _appleLinked = true;
      _facebookLinked = false;
      _appleEmail = 'user@icloud.com';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes liés'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildLinkedAccountsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Comptes liés',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Liez vos comptes sociaux pour une connexion plus rapide. '
              'Vous pourrez vous connecter avec n\'importe lequel de ces comptes.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedAccountsSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Méthodes de connexion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildAccountTile(
            provider: 'Google',
            icon: Icons.g_mobiledata,
            color: Colors.red,
            isLinked: _googleLinked,
            email: _googleEmail,
            onToggle: () => _toggleGoogleAccount(),
          ),
          const Divider(height: 1),
          _buildAccountTile(
            provider: 'Apple',
            icon: Icons.apple,
            color: Colors.black,
            isLinked: _appleLinked,
            email: _appleEmail,
            onToggle: () => _toggleAppleAccount(),
          ),
          const Divider(height: 1),
          _buildAccountTile(
            provider: 'Facebook',
            icon: Icons.facebook,
            color: Colors.blue[800]!,
            isLinked: _facebookLinked,
            email: _facebookEmail,
            onToggle: () => _toggleFacebookAccount(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile({
    required String provider,
    required IconData icon,
    required Color color,
    required bool isLinked,
    required String? email,
    required VoidCallback onToggle,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
      title: Text(provider),
      subtitle: isLinked && email != null
          ? Text(
              'Lié à $email',
              style: const TextStyle(color: Colors.green),
            )
          : Text(
              'Non lié',
              style: TextStyle(color: Colors.grey[600]),
            ),
      trailing: isLinked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _showUnlinkDialog(provider, onToggle),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Délier'),
                ),
              ],
            )
          : TextButton(
              onPressed: _isLoading ? null : onToggle,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Lier'),
            ),
    );
  }

  void _showUnlinkDialog(String provider, VoidCallback onUnlink) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Délier le compte $provider'),
        content: Text(
          'Êtes-vous sûr de vouloir délier votre compte $provider ?\n\n'
          'Vous ne pourrez plus vous connecter avec ce compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onUnlink();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Délier'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleGoogleAccount() async {
    if (_googleLinked) {
      await _unlinkGoogleAccount();
    } else {
      await _linkGoogleAccount();
    }
  }

  Future<void> _toggleAppleAccount() async {
    if (_appleLinked) {
      await _unlinkAppleAccount();
    } else {
      await _linkAppleAccount();
    }
  }

  Future<void> _toggleFacebookAccount() async {
    if (_facebookLinked) {
      await _unlinkFacebookAccount();
    } else {
      await _linkFacebookAccount();
    }
  }

  Future<void> _linkGoogleAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implémenter la liaison Google via l'API
      await Future.delayed(const Duration(seconds: 2)); // Simulation

      setState(() {
        _googleLinked = true;
        _googleEmail = 'user@gmail.com';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Google lié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la liaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implémenter la déliaison Google via l'API
      await Future.delayed(const Duration(seconds: 1)); // Simulation

      setState(() {
        _googleLinked = false;
        _googleEmail = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Google délié'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déliaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _linkAppleAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implémenter la liaison Apple via l'API
      await Future.delayed(const Duration(seconds: 2)); // Simulation

      setState(() {
        _appleLinked = true;
        _appleEmail = 'user@icloud.com';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Apple lié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la liaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlinkAppleAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implémenter la déliaison Apple via l'API
      await Future.delayed(const Duration(seconds: 1)); // Simulation

      setState(() {
        _appleLinked = false;
        _appleEmail = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Apple délié'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déliaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _linkFacebookAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implémenter la liaison Facebook via l'API
      await Future.delayed(const Duration(seconds: 2)); // Simulation

      setState(() {
        _facebookLinked = true;
        _facebookEmail = 'user@facebook.com';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Facebook lié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la liaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlinkFacebookAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implémenter la déliaison Facebook via l'API
      await Future.delayed(const Duration(seconds: 1)); // Simulation

      setState(() {
        _facebookLinked = false;
        _facebookEmail = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Facebook délié'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déliaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
