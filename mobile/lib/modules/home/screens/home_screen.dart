import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';
import '../../../themes/modern_theme.dart';
import '../../trips/screens/my_trips_screen_bloc.dart';
import '../../trips/bloc/trip_bloc.dart';
import '../../trips/models/trip_model.dart';
import '../../trips/widgets/trip_card_widget.dart';
import '../../booking/screens/bookings_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomePage(),
    const _SearchPage(),
    const _BookingsPage(),
    const _MessagesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isAuthenticated = state is AuthAuthenticated;
        
        return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: ModernTheme.primaryBlue,
          unselectedItemColor: ModernTheme.gray400,
          backgroundColor: ModernTheme.white,
          elevation: 8,
          onTap: (index) {
            // Vérifier l'authentification pour certains onglets
            if (!isAuthenticated && (index == 2 || index == 3)) {
              // Réservations (index 2) et Messages (index 3) nécessitent une connexion
              String message = index == 2 
                  ? 'Connectez-vous pour voir vos voyages et réservations'
                  : 'Connectez-vous pour accéder à la messagerie';
                  
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  action: SnackBarAction(
                    label: 'Se connecter',
                    onPressed: () => context.push('/login'),
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Rechercher',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark),
              label: 'Réservations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'Messages',
            ),
          ],
        ),
      );
      },
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: Text(
          'KiloShare',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: ModernTheme.gray700),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.gray100,
                borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
              ),
              child: Icon(Icons.person, color: ModernTheme.primaryBlue),
            ),
            onPressed: () => context.push('/profile/settings'),
            tooltip: 'Profil',
          ),
          const SizedBox(width: ModernTheme.spacing8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInSlideUp(
              delay: Duration(milliseconds: 100),
              child: _buildWelcomeSection(context),
            ),
            FadeInSlideUp(
              delay: Duration(milliseconds: 200),
              child: _buildQuickActionsSection(context),
            ),
            FadeInSlideUp(
              delay: Duration(milliseconds: 300),
              child: _buildRecentTripsSection(context),
            ),
            FadeInSlideUp(
              delay: Duration(milliseconds: 400),
              child: _buildPromotionsSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(ModernTheme.spacing16),
      padding: const EdgeInsets.all(ModernTheme.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ModernTheme.primaryBlue,
            ModernTheme.darkBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
        boxShadow: ModernTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return Text(
                  'Bonjour ${state.user.firstName ?? 'Utilisateur'} 👋',
                  style: TextStyle(
                    color: ModernTheme.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                );
              } else {
                return Text(
                  'Bienvenue sur KiloShare! 👋',
                  style: TextStyle(
                    color: ModernTheme.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return Text(
                  'Partagez vos trajets et économisez sur vos bagages',
                  style: TextStyle(
                    color: ModernTheme.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                );
              } else {
                return Text(
                  'Découvrez une nouvelle façon de voyager léger\nConnectez-vous pour créer vos annonces',
                  style: TextStyle(
                    color: ModernTheme.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.start,
                );
              }
            },
          ),
          const SizedBox(height: ModernTheme.spacing16),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return ModernButton(
                  text: 'Proposer un trajet',
                  onPressed: () => context.push('/trips/create'),
                  icon: Icons.add,
                  backgroundColor: ModernTheme.white,
                  textColor: ModernTheme.primaryBlue,
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: ModernButton(
                        text: 'Se connecter',
                        onPressed: () => context.push('/login'),
                        icon: Icons.login,
                        backgroundColor: ModernTheme.white,
                        textColor: ModernTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: ModernTheme.spacing12),
                    Expanded(
                      child: ModernButton(
                        text: 'Rechercher',
                        onPressed: () => context.push('/trips/search'),
                        icon: Icons.search,
                        style: ModernButtonStyle.outline,
                        textColor: ModernTheme.white,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ModernTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.gray900,
            ),
          ),
          const SizedBox(height: ModernTheme.spacing16),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final isAuthenticated = state is AuthAuthenticated;
              
              return Row(
                children: [
                  Expanded(
                    child: isAuthenticated 
                        ? _buildActionCard(
                            context,
                            Icons.add_location,
                            'Proposer trajet',
                            'Partagez votre voyage',
                            ModernTheme.primaryBlue,
                            () => context.push('/trips/create'),
                          )
                        : _buildActionCard(
                            context,
                            Icons.login,
                            'Se connecter',
                            'Créer une annonce',
                            ModernTheme.primaryBlue,
                            () => context.push('/login'),
                          ),
                  ),
                  const SizedBox(width: ModernTheme.spacing12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      Icons.search,
                      'Chercher trajet',
                      'Trouvez votre voyage',
                      ModernTheme.success,
                      () => context.push('/trips/search'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(ModernTheme.spacing12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: ModernTheme.spacing12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: ModernTheme.gray900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ModernTheme.spacing4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.gray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTripsSection(BuildContext context) {
    return BlocProvider(
      create: (context) => TripBloc()..add(const LoadPublicTrips(limit: 5)),
      child: Padding(
        padding: const EdgeInsets.all(ModernTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trajets disponibles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.gray900,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/trips/search'),
                  child: Text(
                    'Voir tout',
                    style: TextStyle(color: ModernTheme.primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ModernTheme.spacing16),
            BlocConsumer<TripBloc, TripState>(
              listener: (context, state) {
                if (state is TripError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is TripLoading) {
                  return const ModernCard(
                    padding: EdgeInsets.all(ModernTheme.spacing24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (state is PublicTripsLoaded && state.trips.isNotEmpty) {
                  return Column(
                    children: state.trips.map((trip) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TripCardWidget(
                          trip: trip,
                          isCompact: true,
                          showUserInfo: true,
                          onTap: () => context.push('/trips/${trip.id}'),
                        ),
                      )
                    ).toList(),
                  );
                }
                
                // Empty state
                return ModernCard(
                  padding: const EdgeInsets.all(ModernTheme.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        size: 48,
                        color: ModernTheme.gray400,
                      ),
                      const SizedBox(height: ModernTheme.spacing12),
                      Text(
                        'Aucun trajet disponible',
                        style: TextStyle(
                          color: ModernTheme.gray600,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: ModernTheme.spacing8),
                      Text(
                        'Revenez plus tard pour voir les nouveaux trajets',
                        style: TextStyle(
                          color: ModernTheme.gray500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offres spéciales',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.gray900,
            ),
          ),
          const SizedBox(height: ModernTheme.spacing16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ModernTheme.spacing24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ModernTheme.warning, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
              boxShadow: ModernTheme.shadowMedium,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_offer,
                  color: ModernTheme.white,
                  size: 32,
                ),
                const SizedBox(height: ModernTheme.spacing12),
                Text(
                  'Première réservation gratuite!',
                  style: TextStyle(
                    color: ModernTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ModernTheme.spacing8),
                Text(
                  'Profitez de votre premier trajet sans frais de service',
                  style: TextStyle(
                    color: ModernTheme.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPage extends StatelessWidget {
  const _SearchPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: Text(
          'Rechercher',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
      ),
      body: FadeInSlideUp(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(ModernTheme.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(ModernTheme.spacing24),
                  decoration: BoxDecoration(
                    color: ModernTheme.lightBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(ModernTheme.radiusXLarge),
                  ),
                  child: Icon(
                    Icons.search,
                    size: 64,
                    color: ModernTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: ModernTheme.spacing24),
                Text(
                  'Trouvez votre voyage',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.gray900,
                  ),
                ),
                const SizedBox(height: ModernTheme.spacing12),
                Text(
                  'Recherchez parmi tous les voyages disponibles\net trouvez celui qui vous convient',
                  style: TextStyle(
                    color: ModernTheme.gray600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ModernTheme.spacing32),
                ModernButton(
                  text: 'Rechercher des voyages',
                  onPressed: () => context.push('/trips/search'),
                  icon: Icons.search,
                  style: ModernButtonStyle.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsPage extends StatelessWidget {
  const _BookingsPage();

  @override
  Widget build(BuildContext context) {
    return const BookingsListScreen();
  }
}

class _MessagesPage extends StatelessWidget {
  const _MessagesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
      ),
      body: FadeInSlideUp(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(ModernTheme.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(ModernTheme.spacing24),
                  decoration: BoxDecoration(
                    color: ModernTheme.lightBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(ModernTheme.radiusXLarge),
                  ),
                  child: Icon(
                    Icons.message,
                    size: 64,
                    color: ModernTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: ModernTheme.spacing24),
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.gray900,
                  ),
                ),
                const SizedBox(height: ModernTheme.spacing12),
                Text(
                  'La messagerie sera bientôt disponible\npour communiquer avec les autres voyageurs',
                  style: TextStyle(
                    color: ModernTheme.gray600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}