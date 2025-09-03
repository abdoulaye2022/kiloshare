import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class CloudinaryMonitoringDashboard extends StatefulWidget {
  const CloudinaryMonitoringDashboard({super.key});

  @override
  State<CloudinaryMonitoringDashboard> createState() => _CloudinaryMonitoringDashboardState();
}

class _CloudinaryMonitoringDashboardState extends State<CloudinaryMonitoringDashboard> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final CloudinaryMonitoringService _monitoringService = CloudinaryMonitoringService();
  
  CloudinaryUsageStats? _usageStats;
  CloudinaryQuotaStatus? _quotaStatus;
  List<CloudinaryAlert> _alerts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final results = await Future.wait([
        _monitoringService.getUsageStats(),
        _monitoringService.getQuotaStatus(),
      ]);

      setState(() {
        _usageStats = results[0] as CloudinaryUsageStats;
        final quotaResult = results[1] as Map<String, dynamic>;
        _quotaStatus = CloudinaryQuotaStatus.fromJson(quotaResult['quota']);
        _alerts = (quotaResult['alerts'] as List)
            .map((alert) => CloudinaryAlert.fromJson(alert))
            .toList();
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Cloudinary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Aperçu'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistiques'),
            Tab(icon: Icon(Icons.cleaning_services), text: 'Nettoyage'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInitialData,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildStatisticsTab(),
                    _buildCleanupTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAlertsSection(),
          const SizedBox(height: 24),
          _buildQuotaSection(),
          const SizedBox(height: 24),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    if (_alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aucune alerte active',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Alertes (${_alerts.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alerts.map((alert) => _buildAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(CloudinaryAlert alert) {
    Color color = alert.level == 'critical' ? Colors.red : Colors.orange;
    IconData icon = alert.level == 'critical' ? Icons.error : Icons.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: BorderDirectional(
          start: BorderSide(color: color, width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(
                color: color == Colors.red ? Colors.red.shade800 : Colors.orange.shade800, 
                fontWeight: FontWeight.w500
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaSection() {
    if (_quotaStatus == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Utilisation des Quotas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuotaIndicator(
                    'Stockage',
                    _quotaStatus!.storagePercentage,
                    '${_quotaStatus!.storageUsedMb.toStringAsFixed(1)} MB',
                    '${_quotaStatus!.storageLimitMb.toStringAsFixed(1)} MB',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildQuotaIndicator(
                    'Bande passante',
                    _quotaStatus!.bandwidthPercentage,
                    '${_quotaStatus!.bandwidthUsedMb.toStringAsFixed(1)} MB',
                    '${_quotaStatus!.bandwidthLimitMb.toStringAsFixed(1)} MB',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaIndicator(String title, double percentage, String used, String limit) {
    Color color = percentage > 90 
        ? Colors.red 
        : percentage > 75 
            ? Colors.orange 
            : Colors.green;

    return Column(
      children: [
        CircularPercentIndicator(
          radius: 60,
          lineWidth: 8,
          percent: percentage / 100,
          progressColor: color,
          backgroundColor: color.withValues(alpha: 0.2),
          center: Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Text(
          '$used / $limit',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    if (_usageStats == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques Rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard('Images totales', _usageStats!.totalImages.toString()),
                _buildStatCard('Uploads ce mois', _usageStats!.monthlyUploads.toString()),
                _buildStatCard('Taille moyenne', '${_usageStats!.averageSizeMb.toStringAsFixed(1)} MB'),
                _buildStatCard('Compressions', '${_usageStats!.compressionRatio.toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return const Center(
      child: Text('Graphiques détaillés des statistiques'),
    );
  }

  Widget _buildCleanupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions de Nettoyage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Nettoyage Automatique'),
                          onPressed: () => _performCleanup('auto'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Nettoyage Forcé'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          onPressed: () => _performCleanup('force'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Text('Historique des nettoyages et opérations'),
    );
  }

  Future<void> _performCleanup(String type) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Nettoyage en cours...'),
            ],
          ),
        ),
      );

      await _monitoringService.triggerCleanup(type, type == 'force');
      
      if (mounted) {
        Navigator.of(context).pop(); // Fermer dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nettoyage effectué avec succès')),
        );
      }

      _loadInitialData(); // Recharger les données

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Fermer dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du nettoyage: $e')),
        );
      }
    }
  }
}

// Modèles de données pour le monitoring
class CloudinaryUsageStats {
  final int totalImages;
  final int monthlyUploads;
  final double averageSizeMb;
  final double compressionRatio;

  CloudinaryUsageStats({
    required this.totalImages,
    required this.monthlyUploads,
    required this.averageSizeMb,
    required this.compressionRatio,
  });

  factory CloudinaryUsageStats.fromJson(Map<String, dynamic> json) {
    return CloudinaryUsageStats(
      totalImages: json['total_images'] ?? 0,
      monthlyUploads: json['monthly_uploads'] ?? 0,
      averageSizeMb: (json['average_size_mb'] ?? 0.0).toDouble(),
      compressionRatio: (json['compression_ratio'] ?? 0.0).toDouble(),
    );
  }
}

class CloudinaryQuotaStatus {
  final double storagePercentage;
  final double bandwidthPercentage;
  final double storageUsedMb;
  final double storageLimitMb;
  final double bandwidthUsedMb;
  final double bandwidthLimitMb;

  CloudinaryQuotaStatus({
    required this.storagePercentage,
    required this.bandwidthPercentage,
    required this.storageUsedMb,
    required this.storageLimitMb,
    required this.bandwidthUsedMb,
    required this.bandwidthLimitMb,
  });

  factory CloudinaryQuotaStatus.fromJson(Map<String, dynamic> json) {
    return CloudinaryQuotaStatus(
      storagePercentage: (json['storage_percentage'] ?? 0.0).toDouble(),
      bandwidthPercentage: (json['bandwidth_percentage'] ?? 0.0).toDouble(),
      storageUsedMb: (json['storage_used_mb'] ?? 0.0).toDouble(),
      storageLimitMb: (json['storage_limit_mb'] ?? 0.0).toDouble(),
      bandwidthUsedMb: (json['bandwidth_used_mb'] ?? 0.0).toDouble(),
      bandwidthLimitMb: (json['bandwidth_limit_mb'] ?? 0.0).toDouble(),
    );
  }
}

class CloudinaryAlert {
  final String type;
  final String level;
  final String message;

  CloudinaryAlert({
    required this.type,
    required this.level,
    required this.message,
  });

  factory CloudinaryAlert.fromJson(Map<String, dynamic> json) {
    return CloudinaryAlert(
      type: json['type'] ?? '',
      level: json['level'] ?? 'info',
      message: json['message'] ?? '',
    );
  }
}

// Service pour les appels API de monitoring
class CloudinaryMonitoringService {
  final Dio _dio = Dio();
  static const String baseUrl = 'https://api.kiloshare.ca/v1'; // Remplacer par votre URL

  Future<CloudinaryUsageStats> getUsageStats({String timeframe = 'monthly'}) async {
    final response = await _dio.get(
      '$baseUrl/admin/cloudinary/usage',
      queryParameters: {'timeframe': timeframe},
    );

    if (response.statusCode == 200 && response.data['success']) {
      return CloudinaryUsageStats.fromJson(response.data['data']);
    }

    throw Exception('Erreur lors de la récupération des statistiques');
  }

  Future<Map<String, dynamic>> getQuotaStatus() async {
    final response = await _dio.get('$baseUrl/admin/cloudinary/quota');

    if (response.statusCode == 200 && response.data['success']) {
      return response.data['data'];
    }

    throw Exception('Erreur lors de la vérification des quotas');
  }

  Future<void> triggerCleanup(String type, bool force) async {
    final response = await _dio.post(
      '$baseUrl/admin/cloudinary/cleanup',
      data: {
        'type': type,
        'force': force,
      },
    );

    if (response.statusCode != 200 || !response.data['success']) {
      throw Exception(response.data['message'] ?? 'Erreur lors du nettoyage');
    }
  }
}