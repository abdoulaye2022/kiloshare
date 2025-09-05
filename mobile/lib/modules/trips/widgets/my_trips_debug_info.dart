import 'package:flutter/material.dart';
import '../services/my_trips_state_manager.dart';

/// Widget de debug pour afficher l'état du gestionnaire MyTripsStateManager
/// Utile pendant le développement pour vérifier que la gestion d'état fonctionne
class MyTripsDebugInfo extends StatefulWidget {
  const MyTripsDebugInfo({super.key});

  @override
  State<MyTripsDebugInfo> createState() => _MyTripsDebugInfoState();
}

class _MyTripsDebugInfoState extends State<MyTripsDebugInfo> {
  late MyTripsStateManager _stateManager;

  @override
  void initState() {
    super.initState();
    _stateManager = MyTripsStateManager.instance;
    _stateManager.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _stateManager.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛠️ Debug Info - My Trips State Manager',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          
          // Données brutes
          Text('📊 Données brutes:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700])),
          Text('  • Total trips: ${_stateManager.allTrips.length}'),
          Text('  • My trips: ${_stateManager.myTrips.length}'),
          Text('  • Drafts: ${_stateManager.drafts.length}'),
          Text('  • Favorites: ${_stateManager.favorites.length}'),
          
          const SizedBox(height: 8),
          
          // Données filtrées
          Text('🔍 Données filtrées:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green[700])),
          Text('  • Filtered trips: ${_stateManager.filteredTrips.length}'),
          Text('  • Filtered drafts: ${_stateManager.filteredDrafts.length}'),
          Text('  • Filtered favorites: ${_stateManager.filteredFavorites.length}'),
          
          const SizedBox(height: 8),
          
          // États de loading
          Text('⏳ États de loading:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[700])),
          Text('  • Loading trips: ${_stateManager.isLoadingTrips}'),
          Text('  • Loading drafts: ${_stateManager.isLoadingDrafts}'),
          Text('  • Loading favorites: ${_stateManager.isLoadingFavorites}'),
          
          const SizedBox(height: 8),
          
          // Filtres actifs
          Text('🎛️ Filtres actifs:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple[700])),
          Text('  • Status: ${_stateManager.statusFilter}'),
          Text('  • Sort by: ${_stateManager.sortBy} (${_stateManager.sortAscending ? "↑" : "↓"})'),
          Text('  • Search: "${_stateManager.searchQuery}"'),
          Text('  • Transport: ${_stateManager.transportFilter}'),
          Text('  • Advanced filters: ${_stateManager.hasAdvancedFilters()}'),
          
          const SizedBox(height: 12),
          
          // Actions de test
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _stateManager.loadAllData(force: true),
                child: const Text('Refresh All'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _stateManager.invalidateCache(),
                child: const Text('Clear Cache'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}