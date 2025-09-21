import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  // Privacy settings state
  bool _profileVisibility = true;
  bool _showEmail = false;
  bool _showPhone = false;
  bool _allowMessages = true;
  bool _dataProcessingConsent = true;
  bool _marketingConsent = false;
  bool _analyticsConsent = true;
  bool _locationTracking = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confidentialité'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileVisibilitySection(),
            const SizedBox(height: 16),
            _buildDataConsentSection(),
            const SizedBox(height: 16),
            _buildDataManagementSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileVisibilitySection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visibilité du profil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contrôlez qui peut voir vos informations',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          _buildPrivacyTile(
            icon: Icons.visibility,
            title: 'Profil public',
            subtitle: 'Votre profil est visible par tous les utilisateurs',
            value: _profileVisibility,
            onChanged: (value) {
              setState(() {
                _profileVisibility = value;
              });
            },
          ),
          _buildPrivacyTile(
            icon: Icons.email,
            title: 'Afficher l\'email',
            subtitle: 'Montrer votre adresse email aux autres utilisateurs',
            value: _showEmail,
            onChanged: (value) {
              setState(() {
                _showEmail = value;
              });
            },
            enabled: _profileVisibility,
          ),
          _buildPrivacyTile(
            icon: Icons.phone,
            title: 'Afficher le téléphone',
            subtitle: 'Montrer votre numéro aux autres utilisateurs',
            value: _showPhone,
            onChanged: (value) {
              setState(() {
                _showPhone = value;
              });
            },
            enabled: _profileVisibility,
          ),
          _buildPrivacyTile(
            icon: Icons.message,
            title: 'Autoriser les messages',
            subtitle: 'Permettre aux utilisateurs de vous contacter',
            value: _allowMessages,
            onChanged: (value) {
              setState(() {
                _allowMessages = value;
              });
            },
          ),
          _buildPrivacyTile(
            icon: Icons.location_on,
            title: 'Suivi de localisation',
            subtitle: 'Améliorer les recommandations basées sur votre position',
            value: _locationTracking,
            onChanged: (value) {
              setState(() {
                _locationTracking = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataConsentSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consentements RGPD',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gérez vos consentements selon le RGPD',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          _buildConsentTile(
            icon: Icons.shield,
            title: 'Traitement des données',
            subtitle: 'Consentement pour le fonctionnement du service',
            value: _dataProcessingConsent,
            onChanged: (value) {
              if (!value) {
                _showDataProcessingWarning();
              } else {
                setState(() {
                  _dataProcessingConsent = value;
                });
              }
            },
            isRequired: true,
          ),
          _buildConsentTile(
            icon: Icons.trending_up,
            title: 'Données analytiques',
            subtitle: 'Amélioration de l\'expérience utilisateur',
            value: _analyticsConsent,
            onChanged: (value) {
              setState(() {
                _analyticsConsent = value;
              });
            },
          ),
          _buildConsentTile(
            icon: Icons.campaign,
            title: 'Communications marketing',
            subtitle: 'Offres personnalisées et promotions',
            value: _marketingConsent,
            onChanged: (value) {
              setState(() {
                _marketingConsent = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Gestion des données',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildActionTile(
            icon: Icons.download,
            title: 'Télécharger mes données',
            subtitle: 'Obtenez une copie de toutes vos données',
            onTap: () => _exportData(),
          ),
          _buildActionTile(
            icon: Icons.history,
            title: 'Historique de confidentialité',
            subtitle: 'Voir les modifications de vos paramètres',
            onTap: () => _showPrivacyHistory(),
          ),
          _buildActionTile(
            icon: Icons.info,
            title: 'Politique de confidentialité',
            subtitle: 'Comment nous traitons vos données',
            onTap: () => _showPrivacyPolicy(),
          ),
          _buildActionTile(
            icon: Icons.contact_support,
            title: 'Délégué à la protection des données',
            subtitle: 'Contactez notre DPO',
            onTap: () => _contactDPO(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (enabled ? Theme.of(context).primaryColor : Colors.grey)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? Theme.of(context).primaryColor : Colors.grey,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      value: enabled ? value : false,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildConsentTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isRequired = false,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isRequired ? Colors.orange : Theme.of(context).primaryColor)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isRequired ? Colors.orange : Theme.of(context).primaryColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (isRequired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Requis',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showDataProcessingWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consentement requis'),
        content: const Text(
          'Ce consentement est nécessaire pour le fonctionnement de l\'application. '
          'Sans ce consentement, vous ne pourrez pas utiliser nos services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Télécharger mes données'),
        content: const Text(
          'Nous allons préparer un fichier avec toutes vos données personnelles. '
          'Vous recevrez un lien de téléchargement par email dans les 24 heures.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demande d\'export envoyée. Vous recevrez un email sous 24h.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique de confidentialité'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dernières modifications :'),
            SizedBox(height: 12),
            Text('• 15/12/2024 - Consentement marketing désactivé'),
            Text('• 10/12/2024 - Profil rendu public'),
            Text('• 01/12/2024 - Compte créé'),
          ],
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

  void _showPrivacyPolicy() {
    context.push('/privacy-policy'); // TODO: Créer cette route
  }

  void _contactDPO() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacter le DPO'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Délégué à la Protection des Données'),
            SizedBox(height: 8),
            Text('Email: dpo@kiloshare.com'),
            Text('Adresse: 123 Rue de la Confidentialité, 75001 Paris'),
            SizedBox(height: 12),
            Text(
              'Le DPO est à votre disposition pour toute question concernant '
              'le traitement de vos données personnelles.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Ouvrir l'application email
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ouverture de l\'application email...')),
              );
            },
            child: const Text('Envoyer un email'),
          ),
        ],
      ),
    );
  }
}