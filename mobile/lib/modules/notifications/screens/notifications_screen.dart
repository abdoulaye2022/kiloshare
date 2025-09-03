import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/notification_model.dart';
import '../services/notification_api_service.dart';
import '../widgets/notification_item_widget.dart';
import '../../../widgets/loading_indicator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final NotificationApiService _notificationService = NotificationApiService();
  final ScrollController _scrollController = ScrollController();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _selectedFilter;
  
  late TabController _tabController;
  final List<String> _tabs = ['Toutes', 'Non lues', 'Lues'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _notifications.clear();
      }
    });

    try {
      bool? isReadFilter;
      if (_tabController.index == 1) {
        isReadFilter = false; // Non lues
      } else if (_tabController.index == 2) {
        isReadFilter = true; // Lues
      }

      final notifications = await _notificationService.getNotifications(
        page: _currentPage,
        limit: 20,
        isRead: isReadFilter,
        type: _selectedFilter,
      );

      setState(() {
        if (refresh) {
          _notifications = notifications;
        } else {
          _notifications.addAll(notifications);
        }
        _hasMore = notifications.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoading || !_hasMore) return;

    _currentPage++;
    await _loadNotifications();
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications(refresh: true);
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      await _refreshNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications ont été marquées comme lues'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filtrer les notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('Toutes', null),
              _buildFilterOption('Voyages', 'trip_booked'),
              _buildFilterOption('Messages', 'message_received'),
              _buildFilterOption('Paiements', 'payment_received'),
              _buildFilterOption('Système', 'system_update'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterOption(String label, String? filterValue) {
    return RadioListTile<String?>(
      title: Text(label),
      value: filterValue,
      groupValue: _selectedFilter,
      onChanged: (String? value) {
        setState(() {
          _selectedFilter = value;
        });
        Navigator.of(context).pop();
        _refreshNotifications();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          onTap: (index) {
            _refreshNotifications();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtrer',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'mark_all_read':
                  _markAllAsRead();
                  break;
                case 'settings':
                  GoRouter.of(context).push('/notifications/settings');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 8),
                    Text('Tout marquer comme lu'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildNotificationsList()).toList(),
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(
        child: LoadingIndicator(message: 'Chargement des notifications...'),
      );
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final notification = _notifications[index];
          return NotificationItemWidget(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onMarkAsRead: () => _markNotificationAsRead(notification),
            onDelete: () => _deleteNotification(notification),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_tabController.index) {
      case 1:
        message = 'Aucune notification non lue';
        icon = Icons.notifications_none;
        break;
      case 2:
        message = 'Aucune notification lue';
        icon = Icons.notifications_off;
        break;
      default:
        message = 'Aucune notification';
        icon = Icons.notifications_none;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous serez notifié des mises à jour importantes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // Marquer comme lue si pas encore lu
    if (!notification.isRead) {
      await _markNotificationAsRead(notification);
    }

    // Navigation basée sur le type de notification
    if (notification.actionUrl != null) {
      GoRouter.of(context).push(notification.actionUrl!);
    } else {
      // Navigation par défaut basée sur le type
      switch (notification.type) {
        case 'trip_booked':
        case 'trip_confirmed':
          if (notification.data?['trip_id'] != null) {
            GoRouter.of(context).push('/trips/${notification.data!['trip_id']}');
          }
          break;
        case 'message_received':
          GoRouter.of(context).push('/messages');
          break;
        case 'payment_received':
          GoRouter.of(context).push('/wallet');
          break;
        // Ajouter d'autres types selon les besoins
      }
    }
  }

  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markAsRead(notification.id);
      
      // Mettre à jour localement
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index >= 0) {
        setState(() {
          _notifications[index] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du marquage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    // Confirmation de suppression
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer la notification'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette notification ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _notificationService.deleteNotification(notification.id);
        
        // Supprimer localement
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}