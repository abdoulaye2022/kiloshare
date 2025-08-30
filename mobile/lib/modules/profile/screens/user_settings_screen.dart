import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_event.dart';
import '../../auth/blocs/auth/auth_state.dart';
import '../../auth/models/user_model.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          User? user;

          if (state is AuthAuthenticated) {
            user = state.user;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildUserHeader(context, user),
                const SizedBox(height: 16),
                _buildAccountSection(context, user),
                const SizedBox(height: 16),
                _buildSecuritySection(context),
                const SizedBox(height: 16),
                _buildPreferencesSection(context),
                const SizedBox(height: 16),
                _buildSupportSection(context),
                const SizedBox(height: 16),
                _buildDangerSection(context),
                const SizedBox(height: 24),
                _buildAppInfo(context),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, User? user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: CircleAvatar(
              radius: 37,
              backgroundImage: user?.profilePicture != null
                  ? NetworkImage(user!.profilePicture!)
                  : null,
              child: user?.profilePicture == null
                  ? Text(
                      _getInitials(user),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getDisplayName(user),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user!.email,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
          if (user?.isVerified == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Compte vérifié',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getInitials(User? user) {
    if (user == null) return 'U';
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    if (firstName.isEmpty && lastName.isEmpty) return 'U';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
  }

  String _getDisplayName(User? user) {
    if (user == null) return 'Utilisateur';
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    if (firstName.isEmpty && lastName.isEmpty) return 'Utilisateur';
    return '$firstName $lastName'.trim();
  }

  Widget _buildAccountSection(BuildContext context, User? user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Compte',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.account_balance_wallet,
            title: 'Portefeuille',
            subtitle: 'Gérer vos paiements et revenus',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.history,
            title: 'Historique des voyages',
            subtitle: 'Vos trajets passés et futurs',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.star,
            title: 'Avis et évaluations',
            subtitle: 'Consultez vos avis reçus et donnés',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sécurité',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            title: 'Changer le mot de passe',
            subtitle: 'Modifiez votre mot de passe',
            onTap: () => context.push('/profile/change-password'),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.security,
            title: 'Authentification à deux facteurs',
            subtitle: 'Renforcez la sécurité de votre compte',
            trailing: Switch(
              value: false,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
                );
              },
            ),
            onTap: null,
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.link,
            title: 'Comptes liés',
            subtitle: 'Gérer vos connexions sociales',
            onTap: () => context.push('/profile/linked-accounts'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Préférences',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Gérer vos préférences de notifications',
            onTap: () => context.push('/profile/notifications'),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Confidentialité',
            subtitle: 'Contrôlez vos données personnelles',
            onTap: () => context.push('/profile/privacy'),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.palette_outlined,
            title: 'Thème',
            subtitle: 'Choisir le thème de l\'application',
            trailing: DropdownButton<String>(
              value: 'Système',
              underline: const SizedBox(),
              items: ['Clair', 'Sombre', 'Système']
                  .map((theme) => DropdownMenuItem(
                        value: theme,
                        child: Text(theme),
                      ))
                  .toList(),
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
                );
              },
            ),
            onTap: null,
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.language,
            title: 'Langue',
            subtitle: 'Français',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: 'Centre d\'aide',
            subtitle: 'FAQ et guides d\'utilisation',
            onTap: () => _launchUrl('https://help.kiloshare.com'),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.chat_bubble_outline,
            title: 'Nous contacter',
            subtitle: 'Assistance et support technique',
            onTap: () => _launchUrl('mailto:support@kiloshare.com'),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.star_outline,
            title: 'Noter l\'application',
            subtitle: 'Donnez votre avis sur les stores',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Redirection vers le store...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.red.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Zone de danger',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.logout,
            title: 'Se déconnecter',
            subtitle: 'Déconnecter ce compte de l\'appareil',
            titleColor: Colors.red[700],
            onTap: () => _showLogoutDialog(context),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.delete_forever,
            title: 'Supprimer le compte',
            subtitle: 'Suppression définitive et irréversible',
            titleColor: Colors.red[700],
            onTap: () => context.push('/profile/delete-account'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.apps,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'KiloShare',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${_packageInfo?.version ?? '1.0.0'} (${_packageInfo?.buildNumber ?? '1'})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Partagez vos trajets, économisez sur vos bagages',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir $url')),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter de votre compte ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}