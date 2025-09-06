import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../services/notification_preferences_service.dart';
import '../../auth/services/auth_service.dart';

class NotificationSettingsScreenEnhanced extends StatefulWidget {
  const NotificationSettingsScreenEnhanced({super.key});

  @override
  State<NotificationSettingsScreenEnhanced> createState() => _NotificationSettingsScreenEnhancedState();
}

class _NotificationSettingsScreenEnhancedState extends State<NotificationSettingsScreenEnhanced> {
  late final NotificationPreferencesService _preferencesService;
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _preferences;
  String? _error;

  // Local state variables for UI
  Map<String, dynamic> _localPreferences = {};

  @override
  void initState() {
    super.initState();
    _preferencesService = NotificationPreferencesService(
      authService: AuthService.instance,
    );
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await _preferencesService.getUserPreferences();
      if (prefs != null) {
        setState(() {
          _preferences = prefs;
          _localPreferences = Map<String, dynamic>.from(prefs);
          _isLoading = false;
        });
      } else {
        // Utiliser les préférences par défaut si pas encore configurées
        final defaultPrefs = _preferencesService.getDefaultPreferences();
        setState(() {
          _preferences = defaultPrefs;
          _localPreferences = Map<String, dynamic>.from(defaultPrefs);
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

  Future<void> _savePreference(String key, dynamic value) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _preferencesService.updateGeneralSetting(key, value);
      
      // Mettre à jour les préférences locales
      if (mounted) {
        setState(() {
          _updateLocalPreference(key, value);
          _isSaving = false;
        });
      }
      
      _showSuccessSnackBar('Préférence mise à jour');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _saveCategoryPreference(String category, String type, bool value) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final updates = <String, dynamic>{};
      updates['${category}_$type'] = value;
      
      await _preferencesService.updateUserPreferences(updates);
      
      // Mettre à jour les préférences locales
      if (mounted) {
        setState(() {
          _updateLocalCategoryPreference(category, type, value);
          _isSaving = false;
        });
      }
      
      _showSuccessSnackBar('Préférence mise à jour');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _saveQuietHours({
    bool? enabled,
    String? startTime,
    String? endTime,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _preferencesService.updateQuietHours(
        enabled: enabled,
        startTime: startTime,
        endTime: endTime,
      );
      
      // Mettre à jour les préférences locales
      if (mounted) {
        setState(() {
          if (enabled != null) {
            _localPreferences['quiet_hours']['enabled'] = enabled;
          }
          if (startTime != null) {
            _localPreferences['quiet_hours']['start'] = startTime;
          }
          if (endTime != null) {
            _localPreferences['quiet_hours']['end'] = endTime;
          }
          _isSaving = false;
        });
      }
      
      _showSuccessSnackBar('Heures calmes mises à jour');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await _showConfirmDialog(
      'Réinitialiser les préférences',
      'Êtes-vous sûr de vouloir réinitialiser toutes les préférences aux valeurs par défaut ?',
    );

    if (!confirm) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final newPrefs = await _preferencesService.resetToDefaults();
      
      if (mounted) {
        setState(() {
          _preferences = newPrefs;
          _localPreferences = Map<String, dynamic>.from(newPrefs);
          _isSaving = false;
        });
      }
      
      _showSuccessSnackBar('Préférences réinitialisées');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showErrorSnackBar(e.toString());
      }
    }
  }

  void _updateLocalPreference(String key, dynamic value) {
    if (_localPreferences['general'] != null) {
      _localPreferences['general'][key] = value;
    }
  }

  void _updateLocalCategoryPreference(String category, String type, bool value) {
    if (_localPreferences['categories'] != null && 
        _localPreferences['categories'][category] != null) {
      _localPreferences['categories'][category][type] = value;
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showTimePicker({required bool isStartTime}) async {
    final currentTime = isStartTime 
        ? _localPreferences['quiet_hours']['start'] 
        : _localPreferences['quiet_hours']['end'];
    
    // Parse current time
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]), 
      minute: int.parse(parts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00';
      
      if (isStartTime) {
        await _saveQuietHours(startTime: timeString);
      } else {
        await _saveQuietHours(endTime: timeString);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPreferences,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Text('Réinitialiser'),
              ),
            ],
            onSelected: (value) {
              if (value == 'reset') {
                _resetToDefaults();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF2563EB),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGeneralSection(),
            const SizedBox(height: 24),
            _buildQuietHoursSection(),
            const SizedBox(height: 24),
            _buildCategoriesSection(),
          ],
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGeneralSection() {
    final general = _localPreferences['general'] ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Canaux de Notification',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              'Notifications Push',
              'Recevoir des notifications sur votre appareil',
              general['push_enabled'] ?? true,
              Icons.notifications,
              (value) => _savePreference('push_enabled', value),
            ),
            _buildSwitchTile(
              'Notifications Email',
              'Recevoir des emails de notification',
              general['email_enabled'] ?? true,
              Icons.email,
              (value) => _savePreference('email_enabled', value),
            ),
            _buildSwitchTile(
              'Notifications SMS',
              'Recevoir des SMS de notification',
              general['sms_enabled'] ?? true,
              Icons.sms,
              (value) => _savePreference('sms_enabled', value),
            ),
            _buildSwitchTile(
              'Notifications In-App',
              'Affichage des notifications dans l\'app',
              general['in_app_enabled'] ?? true,
              Icons.notification_important,
              (value) => _savePreference('in_app_enabled', value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Marketing',
              'Recevoir les offres et actualités',
              general['marketing_enabled'] ?? false,
              Icons.campaign,
              (value) => _savePreference('marketing_enabled', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursSection() {
    final quietHours = _localPreferences['quiet_hours'] ?? {};
    final enabled = quietHours['enabled'] ?? true;
    final startTime = quietHours['start'] ?? '22:00:00';
    final endTime = quietHours['end'] ?? '08:00:00';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heures Calmes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Définir une période où vous ne souhaitez pas recevoir de notifications.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Activer les heures calmes'),
              subtitle: enabled 
                  ? Text('De ${_preferencesService.formatTimeForDisplay(startTime)} à ${_preferencesService.formatTimeForDisplay(endTime)}')
                  : const Text('Désactivé'),
              value: enabled,
              activeColor: const Color(0xFF2563EB),
              onChanged: (value) => _saveQuietHours(enabled: value),
            ),
            if (enabled) ...[
              const Divider(),
              ListTile(
                title: const Text('Heure de début'),
                subtitle: Text(_preferencesService.formatTimeForDisplay(startTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _showTimePicker(isStartTime: true),
              ),
              ListTile(
                title: const Text('Heure de fin'),
                subtitle: Text(_preferencesService.formatTimeForDisplay(endTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _showTimePicker(isStartTime: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = _localPreferences['categories'] ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Types de Notifications',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            _buildCategorySection(
              'Mises à jour des trajets',
              'trip_updates',
              categories['trip_updates'] ?? {},
              Icons.route,
            ),
            const Divider(),
            _buildCategorySection(
              'Réservations',
              'booking_updates',
              categories['booking_updates'] ?? {},
              Icons.book_online,
            ),
            const Divider(),
            _buildCategorySection(
              'Paiements',
              'payment_updates',
              categories['payment_updates'] ?? {},
              Icons.payment,
            ),
            const Divider(),
            _buildCategorySection(
              'Alertes de sécurité',
              'security_alerts',
              categories['security_alerts'] ?? {},
              Icons.security,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, String category, Map<String, dynamic> prefs, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: const Color(0xFF2563EB)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Push'),
                  Switch(
                    value: prefs['push'] ?? true,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (value) => _saveCategoryPreference(category, 'push', value),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Email'),
                  Switch(
                    value: prefs['email'] ?? true,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (value) => _saveCategoryPreference(category, 'email', value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      secondary: Icon(icon, color: const Color(0xFF2563EB)),
      activeColor: const Color(0xFF2563EB),
      onChanged: onChanged,
    );
  }
}