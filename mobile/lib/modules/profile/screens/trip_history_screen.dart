import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../trips/models/trip_model.dart';
import '../../trips/services/trip_service.dart';
import '../../trips/widgets/trip_card_widget.dart';
import '../../../themes/modern_theme.dart';
import '../../../services/auth_token_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TripService _tripService = AuthTokenService.instance.tripService;

  // State
  List<Trip> _myTrips = [];
  List<Trip> _completedTrips = [];
  bool _isLoadingMyTrips = true;
  bool _isLoadingCompleted = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTripHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTripHistory() async {
    _loadMyTrips();
    _loadCompletedTrips();
  }

  Future<void> _loadMyTrips() async {
    try {
      setState(() {
        _isLoadingMyTrips = true;
        _error = null;
      });

      final trips = await _tripService.getUserTrips();

      setState(() {
        _myTrips = trips;
        _isLoadingMyTrips = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement: $e';
        _isLoadingMyTrips = false;
      });
    }
  }

  Future<void> _loadCompletedTrips() async {
    try {
      setState(() {
        _isLoadingCompleted = true;
      });

      // Filter completed trips from my trips
      final completedTrips = _myTrips
          .where((trip) => trip.status == TripStatus.completed)
          .toList();

      setState(() {
        _completedTrips = completedTrips;
        _isLoadingCompleted = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCompleted = false;
      });
    }
  }

  Future<void> _refreshTrips() async {
    await _loadTripHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: const Text(
          'Historique des voyages',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: ModernTheme.gray700),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: ModernTheme.gray600,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(
              text: 'Mes voyages',
              icon: Icon(Icons.flight_takeoff, size: 20),
            ),
            Tab(
              text: 'Réservés',
              icon: Icon(Icons.bookmark, size: 20),
            ),
            Tab(
              text: 'Terminés',
              icon: Icon(Icons.history, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyTripsTab(),
          _buildBookedTripsTab(),
          _buildCompletedTripsTab(),
        ],
      ),
    );
  }

  Widget _buildMyTripsTab() {
    if (_isLoadingMyTrips) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(_error!, _loadMyTrips);
    }

    if (_myTrips.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flight_takeoff,
        title: 'Aucun voyage créé',
        subtitle: 'Vous n\'avez pas encore créé de voyage',
        actionLabel: 'Créer un voyage',
        onAction: () => context.push('/trips/create'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTrips.length,
        itemBuilder: (context, index) {
          final trip = _myTrips[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTripCardWithStatus(trip),
          );
        },
      ),
    );
  }

  Widget _buildBookedTripsTab() {
    return _buildEmptyState(
      icon: Icons.bookmark_border,
      title: 'Aucune réservation',
      subtitle: 'Vous n\'avez pas encore réservé de voyage',
      actionLabel: 'Rechercher des voyages',
      onAction: () => context.go('/trips/search'),
    );
  }

  Widget _buildCompletedTripsTab() {
    if (_isLoadingCompleted) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_completedTrips.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Aucun voyage terminé',
        subtitle: 'Vous n\'avez pas encore de voyages terminés',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedTrips.length,
      itemBuilder: (context, index) {
        final trip = _completedTrips[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCompletedTripCard(trip),
        );
      },
    );
  }

  Widget _buildTripCardWithStatus(Trip trip) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          TripCardWidget(
            trip: trip,
            onTap: () => context.push('/trips/${trip.id}'),
          ),
          _buildTripStatusBar(trip),
        ],
      ),
    );
  }

  Widget _buildTripStatusBar(Trip trip) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (trip.status) {
      case TripStatus.draft:
        statusColor = Colors.orange;
        statusText = 'Brouillon';
        statusIcon = Icons.edit;
        break;
      case TripStatus.pendingReview:
      case TripStatus.pendingApproval:
        statusColor = Colors.blue;
        statusText = 'En cours de révision';
        statusIcon = Icons.schedule;
        break;
      case TripStatus.active:
        statusColor = Colors.green;
        statusText = 'Publié';
        statusIcon = Icons.visibility;
        break;
      case TripStatus.paused:
        statusColor = Colors.amber;
        statusText = 'En pause';
        statusIcon = Icons.pause;
        break;
      case TripStatus.completed:
        statusColor = Colors.purple;
        statusText = 'Terminé';
        statusIcon = Icons.check_circle;
        break;
      case TripStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Annulé';
        statusIcon = Icons.cancel;
        break;
      case TripStatus.expired:
        statusColor = Colors.grey;
        statusText = 'Expiré';
        statusIcon = Icons.schedule_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusText = trip.status.displayName;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          if (trip.status == TripStatus.draft) ...[
            TextButton.icon(
              onPressed: () => context.push('/trips/${trip.id}/edit'),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(
                foregroundColor: statusColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
          ...[
            Icon(Icons.visibility, color: Colors.grey.shade600, size: 14),
            const SizedBox(width: 4),
            Text(
              '${trip.viewCount}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedTripCard(Trip trip) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          TripCardWidget(
            trip: trip,
            onTap: () => context.push('/trips/${trip.id}'),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Voyage terminé',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Fonctionnalité d\'évaluation bientôt disponible'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star_border, size: 16),
                  label: const Text('Évaluer'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
