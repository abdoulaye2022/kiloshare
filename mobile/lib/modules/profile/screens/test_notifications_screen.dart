import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../auth/services/auth_service.dart';

class TestNotificationsScreen extends StatefulWidget {
  const TestNotificationsScreen({super.key});

  @override
  State<TestNotificationsScreen> createState() => _TestNotificationsScreenState();
}

class _TestNotificationsScreenState extends State<TestNotificationsScreen> {
  final AuthService _authService = AuthService.instance;
  bool _isLoading = false;
  String? _lastResult;
  Map<String, dynamic>? _channelStatus;

  @override
  void initState() {
    super.initState();
    _loadChannelStatus();
  }

  Future<void> _loadChannelStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _authService.dio.get('/test/notifications/channel-status');
      
      if (response.data['success'] == true) {
        setState(() {
          _channelStatus = response.data['data']['channel_status'];
        });
      }
    } catch (e) {
      _showError('Erreur lors du chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestNotification(String type) async {
    setState(() => _isLoading = true);
    
    final testData = _getTestData(type);
    
    try {
      final response = await _authService.dio.post(
        '/test/notifications/send',
        data: {
          'type': type,
          'data': testData,
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _lastResult = 'Notification $type envoyée:\n${response.data['data']['result']}';
        });
        _showSuccess('Notification envoyée avec succès!');
      } else {
        _showError('Erreur: ${response.data['message']}');
      }
    } catch (e) {
      _showError('Erreur lors de l\'envoi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAllPreferences() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _authService.dio.post('/test/notifications/test-all');
      
      if (response.data['success'] == true) {
        setState(() {
          _lastResult = 'Tests complets terminés:\n${response.data['data']}';
        });
        _showSuccess('Tous les tests terminés!');
      } else {
        _showError('Erreur: ${response.data['message']}');
      }
    } catch (e) {
      _showError('Erreur lors des tests: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testWithCustomPreferences() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _authService.dio.post(
        '/test/notifications/test-with-prefs',
        data: {
          'type': 'booking_request',
          'preferences': {
            'push_enabled': false,
            'email_enabled': true,
            'booking_updates_push': false,
            'booking_updates_email': true,
          },
          'data': {'trip_id': 999, 'sender': 'Test User'}
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _lastResult = 'Test avec préférences personnalisées:\n${response.data['data']}';
        });
        _showSuccess('Test avec préférences terminé!');
      } else {
        _showError('Erreur: ${response.data['message']}');
      }
    } catch (e) {
      _showError('Erreur lors du test: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getTestData(String type) {
    switch (type) {
      case 'booking_request':
        return {'trip_id': 123, 'sender': 'Jean Dupont'};
      case 'payment_received':
        return {'amount': 50.0, 'currency': 'EUR'};
      case 'trip_cancelled':
        return {'trip_id': 456, 'reason': 'Imprévu'};
      case 'login_from_new_device':
        return {'device': 'iPhone', 'location': 'Paris'};
      default:
        return {};
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // État des canaux
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'État des Canaux',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _loadChannelStatus,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_channelStatus != null) ...[
                            _buildChannelStatus('Push', _channelStatus!['push']),
                            _buildChannelStatus('Email', _channelStatus!['email']),
                            _buildChannelStatus('SMS', _channelStatus!['sms']),
                            _buildChannelStatus('In-App', _channelStatus!['in_app']),
                            if (_channelStatus!['quiet_hours'] != null)
                              _buildQuietHoursStatus(_channelStatus!['quiet_hours']),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tests individuels
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tests de Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTestButton(
                            'Demande de réservation',
                            () => _sendTestNotification('booking_request'),
                          ),
                          _buildTestButton(
                            'Paiement reçu',
                            () => _sendTestNotification('payment_received'),
                          ),
                          _buildTestButton(
                            'Voyage annulé',
                            () => _sendTestNotification('trip_cancelled'),
                          ),
                          _buildTestButton(
                            'Alerte sécurité',
                            () => _sendTestNotification('login_from_new_device'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tests avancés
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tests Avancés',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _testAllPreferences,
                              child: const Text('Tester Toutes les Préférences'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _testWithCustomPreferences,
                              child: const Text('Tester avec Préférences Personnalisées'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Résultats
                  if (_lastResult != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dernier Résultat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_lastResult!),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildChannelStatus(String name, Map<String, dynamic>? status) {
    if (status == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status['enabled_globally'] == true ? Icons.check_circle : Icons.cancel,
            color: status['enabled_globally'] == true ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('$name: '),
          Text(
            status['enabled_globally'] == true ? 'Activé' : 'Désactivé',
            style: TextStyle(
              color: status['enabled_globally'] == true ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursStatus(Map<String, dynamic> quietHours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            quietHours['currently_in_quiet_hours'] == true ? Icons.bedtime : Icons.wb_sunny,
            color: quietHours['currently_in_quiet_hours'] == true ? Colors.orange : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            quietHours['currently_in_quiet_hours'] == true 
                ? 'En heures calmes' 
                : 'Hors heures calmes',
            style: TextStyle(
              color: quietHours['currently_in_quiet_hours'] == true ? Colors.orange : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(title),
        ),
      ),
    );
  }
}