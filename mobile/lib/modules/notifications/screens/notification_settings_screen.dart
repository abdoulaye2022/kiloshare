import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/notification_api_service.dart';
import '../../../widgets/loading_indicator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationApiService _notificationService = NotificationApiService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Préférences de notification
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _tripUpdates = true;
  bool _bookingUpdates = true;
  bool _paymentUpdates = true;
  bool _messageUpdates = true;
  bool _promotionalUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    
    try {
      final preferences = await _notificationService.getNotificationPreferences();
      
      setState(() {
        _pushNotifications = preferences['push_notifications'] ?? true;
        _emailNotifications = preferences['email_notifications'] ?? true;
        _smsNotifications = preferences['sms_notifications'] ?? false;
        _tripUpdates = preferences['trip_updates'] ?? true;
        _bookingUpdates = preferences['booking_updates'] ?? true;
        _paymentUpdates = preferences['payment_updates'] ?? true;
        _messageUpdates = preferences['message_updates'] ?? true;
        _promotionalUpdates = preferences['promotional_updates'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des préférences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    
    try {
      await _notificationService.updateNotificationPreferences(
        pushNotifications: _pushNotifications,
        emailNotifications: _emailNotifications,
        smsNotifications: _smsNotifications,
        tripUpdates: _tripUpdates,
        bookingUpdates: _bookingUpdates,
        paymentUpdates: _paymentUpdates,
        messageUpdates: _messageUpdates,
        promotionalUpdates: _promotionalUpdates,
      );
      
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Préférences sauvegardées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.sendTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification de test envoyée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: null,
        body: LoadingIndicator(message: 'Chargement des préférences...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de notification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePreferences,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sauvegarder'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Canaux de notification',
              [
                _buildSwitchTile(
                  'Notifications push',
                  'Recevoir les notifications sur votre appareil',
                  _pushNotifications,
                  (value) => setState(() => _pushNotifications = value),
                  Icons.notifications_active,
                ),
                _buildSwitchTile(
                  'Notifications email',
                  'Recevoir les notifications par email',
                  _emailNotifications,
                  (value) => setState(() => _emailNotifications = value),
                  Icons.email,
                ),
                _buildSwitchTile(
                  'Notifications SMS',
                  'Recevoir les notifications par SMS',
                  _smsNotifications,
                  (value) => setState(() => _smsNotifications = value),
                  Icons.sms,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Types de notifications',
              [
                _buildSwitchTile(
                  'Mises à jour de voyages',
                  'Modifications, annulations, confirmations',
                  _tripUpdates,
                  (value) => setState(() => _tripUpdates = value),
                  Icons.flight,
                ),
                _buildSwitchTile(
                  'Mises à jour de réservations',
                  'Nouvelles réservations, modifications',
                  _bookingUpdates,
                  (value) => setState(() => _bookingUpdates = value),
                  Icons.book,
                ),
                _buildSwitchTile(
                  'Mises à jour de paiements',
                  'Paiements reçus, remboursements',
                  _paymentUpdates,
                  (value) => setState(() => _paymentUpdates = value),
                  Icons.payment,
                ),
                _buildSwitchTile(
                  'Nouveaux messages',
                  'Messages des autres utilisateurs',
                  _messageUpdates,
                  (value) => setState(() => _messageUpdates = value),
                  Icons.message,
                ),
                _buildSwitchTile(
                  'Mises à jour promotionnelles',
                  'Offres spéciales, nouveautés',
                  _promotionalUpdates,
                  (value) => setState(() => _promotionalUpdates = value),
                  Icons.local_offer,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildTestSection(),
            const SizedBox(height: 32),
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ),
      value: value,
      onChanged: onChanged,
      secondary: Icon(
        icon,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Test de notification',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Envoyer une notification de test pour vérifier que tout fonctionne correctement.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer un test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Text(
                  'À propos des notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              'Les notifications push nécessitent l\'autorisation de votre appareil.',
            ),
            _buildInfoItem(
              'Les notifications critiques (sécurité, paiements) ne peuvent pas être désactivées.',
            ),
            _buildInfoItem(
              'Vous pouvez modifier ces préférences à tout moment.',
            ),
            _buildInfoItem(
              'Les préférences sont synchronisées sur tous vos appareils.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}