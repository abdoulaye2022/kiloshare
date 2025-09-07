import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../../auth/services/auth_service.dart';
import '../../../services/offline_bookings_service.dart';
import '../../../widgets/offline_indicator.dart';
import '../../../widgets/cached_data_wrapper.dart';

class BookingsListScreenCached extends StatefulWidget {
  const BookingsListScreenCached({super.key});

  @override
  State<BookingsListScreenCached> createState() => _BookingsListScreenCachedState();
}

class _BookingsListScreenCachedState extends State<BookingsListScreenCached> with SingleTickerProviderStateMixin {
  final OfflineBookingsService _bookingsService = OfflineBookingsService();
  final AuthService _authService = AuthService.instance;
  
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user.uuid;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
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
        title: const Text('Mes Réservations'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Envoyées'),
            Tab(text: 'Reçues'),
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
                // Onglet Réservations Envoyées avec Cache
                CachedDataWrapper<List<BookingModel>>(
                  onlineDataLoader: () => _bookingsService.getMyBookings(),
                  cachedDataLoader: () => _bookingsService.getCachedBookings(),
                  onDataLoaded: (bookings) {
                    // Callback appelé quand les données sont chargées avec succès
                  },
                  cacheType: CacheDataType.myBookings,
                  builder: (context, bookings, isLoading, error) {
                    final sentBookings = bookings?.where((b) => 
                      b.senderId == _currentUserId).toList() ?? [];
                    return _buildBookingsTab(
                      context, 
                      sentBookings, 
                      isLoading, 
                      error, 
                      'Aucune réservation envoyée',
                      _bookingsService.isOffline
                    );
                  },
                ),
                
                // Onglet Réservations Reçues avec Cache
                CachedDataWrapper<List<BookingModel>>(
                  onlineDataLoader: () => _bookingsService.getMyBookings(),
                  cachedDataLoader: () => _bookingsService.getCachedBookings(),
                  onDataLoaded: (bookings) {
                    // Callback appelé quand les données sont chargées avec succès
                  },
                  cacheType: CacheDataType.myBookings,
                  builder: (context, bookings, isLoading, error) {
                    final receivedBookings = bookings?.where((b) => 
                      b.receiverId == _currentUserId).toList() ?? [];
                    return _buildBookingsTab(
                      context, 
                      receivedBookings, 
                      isLoading, 
                      error, 
                      'Aucune réservation reçue',
                      _bookingsService.isOffline
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab(
    BuildContext context, 
    List<BookingModel> bookings, 
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

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              booking.packageDescription,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Poids: ${booking.weightKg}kg'),
                Text('Prix proposé: \$${booking.proposedPrice.toStringAsFixed(2)}'),
                Text('Statut: ${_getStatusText(booking.status)}'),
                if (isOffline)
                  const Text(
                    'Données en cache',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _getStatusIcon(booking.status),
                if (isOffline)
                  const Icon(Icons.cached, size: 16, color: Colors.blue),
              ],
            ),
            onTap: isOffline 
              ? () => _showOfflineMessage(context)
              : () {
                  context.push('/booking-details/${booking.id}');
                },
          ),
        );
      },
    );
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'En attente';
      case BookingStatus.accepted:
        return 'Acceptée';
      case BookingStatus.cancelled:
        return 'Annulée';
      case BookingStatus.completed:
        return 'Terminée';
      default:
        return 'Inconnu';
    }
  }

  Widget _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange, size: 20);
      case BookingStatus.accepted:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case BookingStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red, size: 20);
      case BookingStatus.completed:
        return const Icon(Icons.done_all, color: Colors.blue, size: 20);
      default:
        return const Icon(Icons.help, color: Colors.grey, size: 20);
    }
  }

  void _showOfflineMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connexion requise pour voir les détails'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}