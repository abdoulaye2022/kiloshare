import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

enum CacheDataType { myTrips, myBookings, lastSearch }

class CachedDataWrapper<T> extends StatefulWidget {
  final Future<T> Function() onlineDataLoader;
  final Future<T?> Function() cachedDataLoader;
  final Function(T data) onDataLoaded;
  final CacheDataType cacheType;
  final Widget Function(BuildContext context, T? data, bool isLoading, String? error) builder;

  const CachedDataWrapper({
    super.key,
    required this.onlineDataLoader,
    required this.cachedDataLoader,
    required this.onDataLoaded,
    required this.cacheType,
    required this.builder,
  });

  @override
  State<CachedDataWrapper<T>> createState() => _CachedDataWrapperState<T>();
}

class _CachedDataWrapperState<T> extends State<CachedDataWrapper<T>> {
  final ConnectivityService _connectivity = ConnectivityService();
  // final CacheService _cache = CacheService(); // Utilisé indirectement par les callbacks
  
  T? _data;
  bool _isLoading = false;
  String? _error;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _connectivity.addListener(_onConnectivityChanged);
    _loadData();
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _isFromCache) {
      // Récupérer des données fraîches quand on revient online
      _loadData(forceOnline: true);
    }
  }

  Future<void> _loadData({bool forceOnline = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_connectivity.isOnline && !forceOnline) {
        // Essayer d'abord les données online
        try {
          final onlineData = await widget.onlineDataLoader();
          _connectivity.markSyncSuccessful();
          widget.onDataLoaded(onlineData);
          
          setState(() {
            _data = onlineData;
            _isFromCache = false;
            _isLoading = false;
          });
          return;
        } catch (e) {
          // Si ça échoue, utiliser le cache
          debugPrint('Online data failed, falling back to cache: $e');
        }
      }

      // Utiliser les données en cache
      final cachedData = await widget.cachedDataLoader();
      if (cachedData != null) {
        setState(() {
          _data = cachedData;
          _isFromCache = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _connectivity.isOffline 
            ? 'Aucune donnée en cache disponible'
            : 'Erreur de chargement des données';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> refresh() async {
    await _loadData(forceOnline: true);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _connectivity.isOnline ? refresh : () async {},
      child: Column(
        children: [
          if (_isFromCache && _connectivity.isOffline)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cached, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Données en cache',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: widget.builder(context, _data, _isLoading, _error),
          ),
        ],
      ),
    );
  }
}