import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_event.dart';
import '../../auth/blocs/auth/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../../themes/modern_theme.dart';
import '../../../utils/debug_storage_cleaner.dart';

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
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: Text(
          'Paramètres',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: ModernTheme.gray700),
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
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 100),
                  child: _buildUserHeader(context, user),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 150),
                  child: _buildQuickActions(context),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildAccountSection(context, user),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 300),
                  child: _buildSecuritySection(context),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 400),
                  child: _buildPreferencesSection(context),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 500),
                  child: _buildSupportSection(context),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 600),
                  child: _buildDangerSection(context),
                ),
                const SizedBox(height: ModernTheme.spacing16),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 650),
                  child: _buildDebugSection(context),
                ),
                const SizedBox(height: ModernTheme.spacing24),
                FadeInSlideUp(
                  delay: const Duration(milliseconds: 700),
                  child: _buildAppInfo(context),
                ),
                const SizedBox(height: ModernTheme.spacing32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, User? user) {
    // Vérifier l'état d'authentification
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;

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
              backgroundImage: (isAuthenticated && user?.profilePicture != null)
                  ? NetworkImage(user!.profilePicture!)
                  : null,
              child: (isAuthenticated && user?.profilePicture == null)
                  ? Text(
                      _getInitials(user),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : !isAuthenticated
                      ? const Icon(
                          Icons.person_outline,
                          size: 40,
                          color: Colors.white,
                        )
                      : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAuthenticated ? _getDisplayName(user) : 'Visiteur',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (isAuthenticated && user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user!.email,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ] else if (!isAuthenticated) ...[
            const SizedBox(height: 4),
            const Text(
              'Connectez-vous pour accéder à vos paramètres',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (isAuthenticated && user?.isVerified == true) ...[
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _navigateToProfile(context, user),
            icon: Icon(
              isAuthenticated ? Icons.edit : Icons.login,
              size: 18,
            ),
            label: Text(isAuthenticated ? 'Modifier le profil' : 'Se connecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions rapides',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context: context,
                    icon: Icons.add_circle_outline,
                    label: 'Créer un voyage',
                    color: Theme.of(context).primaryColor,
                    onTap: () => context.push('/trips/create'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context: context,
                    icon: Icons.search,
                    label: 'Rechercher',
                    color: Colors.blue,
                    onTap: () => context.push('/trips/search'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context: context,
                    icon: Icons.history,
                    label: 'Mes voyages',
                    color: Colors.purple,
                    onTap: () => context.push('/profile/trip-history'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context: context,
                    icon: Icons.person_outline,
                    label: 'Mon profil',
                    color: Colors.green,
                    onTap: () => _navigateToProfile(context, null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            onTap: () => _navigateToWallet(context),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.history,
            title: 'Historique des voyages',
            subtitle: 'Vos trajets passés et futurs',
            onTap: () => context.push('/profile/trip-history'),
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

  Widget _buildDebugSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.blue.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '🛠️ Debug Tools',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.storage,
            title: 'Inspecter le stockage',
            subtitle: 'Voir le contenu du stockage local',
            titleColor: Colors.blue[700],
            onTap: () async {
              await DebugStorageCleaner.debugSecureStorage();
              await DebugStorageCleaner.debugSharedPreferences();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debug info affichée dans la console'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.cleaning_services,
            title: 'Nettoyer le stockage',
            subtitle: 'Supprimer toutes les sessions persistantes',
            titleColor: Colors.blue[700],
            onTap: () => _showClearStorageDialog(context),
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

  void _navigateToProfile(BuildContext context, User? user) {
    // Vérifier si l'utilisateur est connecté
    final authState = context.read<AuthBloc>().state;
    
    if (authState is AuthAuthenticated) {
      // Utilisateur connecté, permettre la navigation
      context.push('/profile/edit');
    } else {
      // Utilisateur non connecté, rediriger vers la page de login
      context.push('/login');
    }
  }

  void _navigateToWallet(BuildContext context) {
    // Vérifier si l'utilisateur est connecté
    final authState = context.read<AuthBloc>().state;
    
    if (authState is AuthAuthenticated) {
      // Utilisateur connecté, permettre la navigation
      context.push('/profile/wallet');
    } else {
      // Utilisateur non connecté, rediriger vers la page de login
      context.push('/login');
    }
  }

  void _showClearStorageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🧹 Nettoyer le stockage'),
        content: const Text(
          'Cela va supprimer toutes les données stockées localement, y compris les sessions persistantes. Vous devrez vous reconnecter.\n\nÊtes-vous sûr de vouloir continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              try {
                // Nettoyer le stockage
                await DebugStorageCleaner.clearAllStorage();
                
                // Forcer une déconnexion du Bloc
                if (context.mounted) {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Stockage nettoyé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur lors du nettoyage: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Nettoyer'),
          ),
        ],
      ),
    );
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