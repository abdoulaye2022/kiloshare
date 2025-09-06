import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trip_model.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/trip_status_widget.dart';
import '../../../widgets/ellipsis_button.dart';
import '../../../widgets/offline_indicator.dart';
import '../../../widgets/cached_data_wrapper.dart';
import '../../../services/offline_my_trips_service.dart';

class MyTripsScreenCached extends StatefulWidget {
  const MyTripsScreenCached({super.key});

  @override
  State<MyTripsScreenCached> createState() => _MyTripsScreenCachedState();
}

class _MyTripsScreenCachedState extends State<MyTripsScreenCached>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OfflineMyTripsService _tripsService = OfflineMyTripsService();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Annonces'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Actives'),
            Tab(text: 'Brouillons'),
            Tab(text: 'Favoris'),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Onglet Annonces Actives avec Cache
                CachedDataWrapper<List<Trip>>(
                  onlineDataLoader: () => _tripsService.getMyTrips(),
                  cachedDataLoader: () => _tripsService.getCachedTrips(),
                  onDataLoaded: (trips) {
                    // Callback appelé quand les données sont chargées avec succès
                  },
                  cacheType: CacheDataType.myTrips,
                  builder: (context, trips, isLoading, error) {
                    return _buildTripsTab(
                      context, 
                      trips, 
                      isLoading, 
                      error, 
                      'Aucune annonce active',
                      _tripsService.isOffline
                    );
                  },
                ),
                
                // Onglet Brouillons (pas de cache pour les brouillons)
                _buildOfflinePlaceholder('Brouillons non disponibles hors-ligne'),
                
                // Onglet Favoris (pas de cache pour les favoris)
                _buildOfflinePlaceholder('Favoris non disponibles hors-ligne'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tripsService.isOnline 
        ? FloatingActionButton(
            onPressed: () {
              context.push('/create-trip');
            },
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : FloatingActionButton(
            onPressed: () {
              _showOfflineMessage(context);
            },
            backgroundColor: Colors.grey,
            child: const Icon(Icons.add, color: Colors.white),
          ),
    );
  }

  Widget _buildTripsTab(
    BuildContext context, 
    List<Trip>? trips, 
    bool isLoading, 
    String? error,
    String emptyMessage,
    bool isOffline
  ) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isOffline ? 'Aucune donnée en cache' : 'Erreur de chargement',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (trips == null || trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (!isOffline) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  context.push('/create-trip');
                },
                child: const Text('Créer une annonce'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: TripCardWidget(
            trip: trip,
            isAuthenticated: true,
            trailing: isOffline ? null : EllipsisButton(
              onEdit: () {
                context.push('/edit-trip/${trip.uuid}');
              },
              onDelete: () {
                _showDeleteConfirmation(context, trip);
              },
              isOnline: !isOffline,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflinePlaceholder(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showOfflineMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connexion requise pour créer une annonce'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text('Connexion requise pour supprimer une annonce'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}