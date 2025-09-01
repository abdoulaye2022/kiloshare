import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiloshare/modules/profile/models/user_profile.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/profile_info_tab.dart';
import '../widgets/verification_tab.dart';
import '../widgets/trust_badge_widget.dart';
import '../../auth/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isAuthenticated = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthentication();
    
    // Load profile data when screen initializes
    context.read<ProfileBloc>().add(const GetUserProfile());
  }
  
  void _checkAuthentication() async {
    final authService = AuthService.instance;
    final isAuth = await authService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuth;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state is ProfileActionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.action}: ${state.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state is ProfileCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil créé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else if (state is ProfileUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil mis à jour avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else if (state is AvatarUploaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avatar mis à jour avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else if (state is DocumentUploaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document téléchargé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else if (state is DocumentDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document supprimé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return _buildLoadingScreen();
          }
          
          if (state is NoProfile) {
            return _buildNoProfileScreen(context);
          }
          
          if (state is ProfileError && state.error.toString().contains('401')) {
            return _buildUnauthorizedScreen(context);
          }
          
          if (state is ProfileError) {
            return _buildErrorScreen(context, state.message);
          }
          
          if (state is ProfileLoaded) {
            return _buildMainContent(context, state);
          }
          
          if (state is ProfilePartiallyLoaded) {
            return _buildPartialContent(context, state);
          }
          
          // Default case for other states like ProfileActionLoading
          if (state is ProfileActionLoading) {
            return _buildActionLoadingScreen(state.action);
          }
          
          return _buildInitialScreen();
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du profil...'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionLoadingScreen(String action) {
    String message = 'Traitement en cours...';
    switch (action) {
      case 'create':
        message = 'Création du profil...';
        break;
      case 'update':
        message = 'Mise à jour du profil...';
        break;
      case 'upload_avatar':
        message = 'Téléchargement de l\'avatar...';
        break;
      case 'upload_document':
        message = 'Téléchargement du document...';
        break;
      case 'delete_document':
        message = 'Suppression du document...';
        break;
    }
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProfileScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Profil non trouvé',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre profil pour commencer',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _isAuthenticated
                ? ElevatedButton.icon(
                    onPressed: () => context.go('/edit-profile'),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer mon profil'),
                  )
                : ElevatedButton.icon(
                    onPressed: () => context.go('/auth/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Se connecter'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorizedScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Accès non autorisé',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Veuillez vous reconnecter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Se reconnecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ProfileBloc>().add(const GetUserProfile());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Retour à l\'accueil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Text('Initialisation...'),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ProfileLoaded state) {
    final profile = state.profile;
    if (profile == null) {
      return _buildNoProfileScreen(context);
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(context, profile, state.verificationStatus),
              ),
              actions: [
                if (_isAuthenticated)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.go('/edit-profile'),
                  ),
                if (!_isAuthenticated)
                  IconButton(
                    icon: const Icon(Icons.login),
                    onPressed: () => context.go('/auth/login'),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<ProfileBloc>().add(const RefreshAllProfileData());
                  },
                ),
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.person),
                      text: 'Informations',
                    ),
                    Tab(
                      icon: const Icon(Icons.verified_user),
                      text: 'Vérification',
                    ),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            ProfileInfoTab(
              profile: profile,
              isAuthenticated: _isAuthenticated,
              onEdit: _isAuthenticated 
                  ? () => context.go('/edit-profile')
                  : () => context.go('/auth/login'),
            ),
            VerificationTab(
              profile: profile,
              documents: state.documents,
              badges: state.badges,
              verificationStatus: state.verificationStatus,
              onUploadDocument: () => context.go('/upload-document'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialContent(BuildContext context, ProfilePartiallyLoaded state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ProfileBloc>().add(const RefreshAllProfileData());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.errors.isNotEmpty)
            Container(
              color: Colors.orange[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certaines données n\'ont pas pu être chargées:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...state.errors.map((error) => Text(
                    '• $error',
                    style: TextStyle(color: Colors.orange[700]),
                  )),
                ],
              ),
            ),
          Expanded(
            child: state.profile != null
                ? _buildMainContent(context, ProfileLoaded(
                    profile: state.profile,
                    documents: state.documents ?? [],
                    badges: state.badges ?? [],
                    verificationStatus: state.verificationStatus ?? const VerificationStatus(),
                  ))
                : _buildNoProfileScreen(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, profile, verificationStatus) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              _buildAvatar(profile),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.bio!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (profile.badges.isNotEmpty) ...[
                          ...profile.badges.take(3).map((badge) => 
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: TrustBadgeWidget(
                                badge: badge,
                                size: 20,
                              ),
                            ),
                          ),
                          if (profile.badges.length > 3)
                            Text(
                              '+${profile.badges.length - 3}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(profile) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: CircleAvatar(
        radius: 37,
        backgroundImage: profile.avatarUrl != null
            ? NetworkImage(profile.avatarUrl!)
            : null,
        child: profile.avatarUrl == null
            ? Text(
                profile.initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}