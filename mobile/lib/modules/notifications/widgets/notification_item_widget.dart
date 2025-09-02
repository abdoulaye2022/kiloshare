import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';

class NotificationItemWidget extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onDelete;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: notification.isRead ? null : Theme.of(context).primaryColor.withValues(alpha: 0.05),
            border: notification.isRead 
                ? null 
                : Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                                  color: notification.isRead ? null : Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8, top: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildNotificationType(),
                            const Spacer(),
                            Text(
                              _formatDate(notification.createdAt),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      switch (value) {
                        case 'mark_read':
                          onMarkAsRead?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                        case 'navigate':
                          onTap?.call();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      if (!notification.isRead)
                        const PopupMenuItem<String>(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 18),
                              SizedBox(width: 8),
                              Text('Marquer comme lu'),
                            ],
                          ),
                        ),
                      if (notification.actionUrl != null)
                        const PopupMenuItem<String>(
                          value: 'navigate',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new, size: 18),
                              SizedBox(width: 8),
                              Text('Ouvrir'),
                            ],
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18),
                            SizedBox(width: 8),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'trip_booked':
      case 'trip_confirmed':
        icon = Icons.flight;
        color = Colors.blue;
        break;
      case 'trip_cancelled':
        icon = Icons.flight_takeoff;
        color = Colors.red;
        break;
      case 'booking_confirmed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'booking_cancelled':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'message_received':
        icon = Icons.message;
        color = Colors.orange;
        break;
      case 'payment_received':
      case 'payment_processed':
        icon = Icons.payment;
        color = Colors.green;
        break;
      case 'system_update':
        icon = Icons.system_update;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildNotificationType() {
    String label;
    Color color;

    switch (notification.type) {
      case 'trip_booked':
      case 'trip_confirmed':
      case 'trip_cancelled':
        label = 'Voyage';
        color = Colors.blue;
        break;
      case 'booking_confirmed':
      case 'booking_cancelled':
        label = 'Réservation';
        color = Colors.green;
        break;
      case 'message_received':
        label = 'Message';
        color = Colors.orange;
        break;
      case 'payment_received':
      case 'payment_processed':
        label = 'Paiement';
        color = Colors.green;
        break;
      case 'system_update':
        label = 'Système';
        color = Colors.purple;
        break;
      default:
        label = 'Notification';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return '${difference.inMinutes}min';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }
}