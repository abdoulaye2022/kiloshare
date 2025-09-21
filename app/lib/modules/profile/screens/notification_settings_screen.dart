import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Notification settings state
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  
  // Specific notification types
  bool _bookingUpdates = true;
  bool _paymentNotifications = true;
  bool _tripReminders = true;
  bool _promotions = false;
  bool _securityAlerts = true;
  bool _messageNotifications = true;
  bool _reviewRequests = true;
  bool _systemUpdates = false;
  
  // Quiet hours
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);
  bool _quietHoursEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildGeneralSettings(),
            const SizedBox(height: 16),
            _buildNotificationTypes(),
            const SizedBox(height: 16),
            _buildQuietHours(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Moyens de notification',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildNotificationMethodTile(
            icon: Icons.notifications,
            title: 'Notifications push',
            subtitle: 'Notifications dans l\'application',
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
              if (value) {
                _requestNotificationPermissions();
              }
            },
          ),
          _buildNotificationMethodTile(
            icon: Icons.email,
            title: 'Notifications email',
            subtitle: 'Recevoir des emails de notification',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),
          _buildNotificationMethodTile(
            icon: Icons.sms,
            title: 'Notifications SMS',
            subtitle: 'Recevoir des SMS importants',
            value: _smsNotifications,
            onChanged: (value) {
              setState(() {
                _smsNotifications = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTypes() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Types de notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildNotificationTypeTile(
            icon: Icons.luggage,
            title: 'Réservations et voyages',
            subtitle: 'Confirmations, modifications, rappels',
            value: _bookingUpdates,
            onChanged: (value) {
              setState(() {
                _bookingUpdates = value;
              });
            },
            isEssential: true,
          ),
          _buildNotificationTypeTile(
            icon: Icons.payment,
            title: 'Paiements',
            subtitle: 'Confirmations de paiement et factures',
            value: _paymentNotifications,
            onChanged: (value) {
              setState(() {
                _paymentNotifications = value;
              });
            },
            isEssential: true,
          ),
          _buildNotificationTypeTile(
            icon: Icons.schedule,
            title: 'Rappels de voyage',
            subtitle: 'Rappels avant le départ',
            value: _tripReminders,
            onChanged: (value) {
              setState(() {
                _tripReminders = value;
              });
            },
          ),
          _buildNotificationTypeTile(
            icon: Icons.message,
            title: 'Messages',
            subtitle: 'Nouveaux messages de voyageurs',
            value: _messageNotifications,
            onChanged: (value) {
              setState(() {
                _messageNotifications = value;
              });
            },
          ),
          _buildNotificationTypeTile(
            icon: Icons.security,
            title: 'Sécurité',
            subtitle: 'Connexions et activité suspecte',
            value: _securityAlerts,
            onChanged: (value) {
              setState(() {
                _securityAlerts = value;
              });
            },
            isEssential: true,
          ),
          _buildNotificationTypeTile(
            icon: Icons.star,
            title: 'Demandes d\'avis',
            subtitle: 'Invitations à laisser un avis',
            value: _reviewRequests,
            onChanged: (value) {
              setState(() {
                _reviewRequests = value;
              });
            },
          ),
          _buildNotificationTypeTile(
            icon: Icons.local_offer,
            title: 'Promotions',
            subtitle: 'Offres spéciales et réductions',
            value: _promotions,
            onChanged: (value) {
              setState(() {
                _promotions = value;
              });
            },
          ),
          _buildNotificationTypeTile(
            icon: Icons.system_update,
            title: 'Mises à jour',
            subtitle: 'Nouvelles fonctionnalités et améliorations',
            value: _systemUpdates,
            onChanged: (value) {
              setState(() {
                _systemUpdates = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHours() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heures de silence',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Désactivez les notifications non essentielles pendant certaines heures',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.do_not_disturb_on,
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: const Text('Activer les heures de silence'),
            subtitle: _quietHoursEnabled
                ? Text('De ${_formatTime(_quietHoursStart)} à ${_formatTime(_quietHoursEnd)}')
                : const Text('Recevoir toutes les notifications'),
            value: _quietHoursEnabled,
            onChanged: (value) {
              setState(() {
                _quietHoursEnabled = value;
              });
            },
          ),
          if (_quietHoursEnabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.bedtime),
              title: const Text('Début des heures de silence'),
              subtitle: Text(_formatTime(_quietHoursStart)),
              onTap: () => _selectTime(_quietHoursStart, true),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny),
              title: const Text('Fin des heures de silence'),
              subtitle: Text(_formatTime(_quietHoursEnd)),
              onTap: () => _selectTime(_quietHoursEnd, false),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildNotificationTypeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isEssential = false,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isEssential ? Colors.orange : Theme.of(context).primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isEssential ? Colors.orange : Theme.of(context).primaryColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (isEssential)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Important',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: isEssential && !value
          ? null // Empêcher la désactivation des notifications essentielles
          : onChanged,
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(TimeOfDay currentTime, bool isStart) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        if (isStart) {
          _quietHoursStart = selectedTime;
        } else {
          _quietHoursEnd = selectedTime;
        }
      });
      
      // Provide haptic feedback
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _requestNotificationPermissions() async {
    // TODO: Implémenter la demande de permissions de notifications
    // En utilisant flutter_local_notifications ou firebase_messaging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permissions de notifications activées'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}