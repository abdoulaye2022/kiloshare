class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? imageUrl;
  final String? actionUrl;
  final NotificationPriority priority;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.imageUrl,
    this.actionUrl,
    this.priority = NotificationPriority.normal,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'general',
      data: json['data'],
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      imageUrl: json['image_url'],
      actionUrl: json['action_url'],
      priority: NotificationPriority.values.firstWhere(
        (p) => p.toString().split('.').last == (json['priority'] ?? 'normal'),
        orElse: () => NotificationPriority.normal,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'image_url': imageUrl,
      'action_url': actionUrl,
      'priority': priority.toString().split('.').last,
    };
  }

  NotificationModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    String? imageUrl,
    String? actionUrl,
    NotificationPriority? priority,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      priority: priority ?? this.priority,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  NotificationIcon get icon {
    switch (type) {
      case 'trip_booked':
      case 'trip_confirmed':
        return NotificationIcon.booking;
      case 'trip_cancelled':
      case 'trip_rejected':
        return NotificationIcon.cancelled;
      case 'message_received':
        return NotificationIcon.message;
      case 'payment_received':
      case 'payment_processed':
        return NotificationIcon.payment;
      case 'trip_reminder':
        return NotificationIcon.reminder;
      case 'system_update':
      case 'app_update':
        return NotificationIcon.system;
      case 'promotion':
      case 'offer':
        return NotificationIcon.promotion;
      default:
        return NotificationIcon.general;
    }
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

enum NotificationIcon {
  general,
  booking,
  cancelled,
  message,
  payment,
  reminder,
  system,
  promotion,
}

extension NotificationPriorityExtension on NotificationPriority {
  String get displayName {
    switch (this) {
      case NotificationPriority.low:
        return 'Faible';
      case NotificationPriority.normal:
        return 'Normale';
      case NotificationPriority.high:
        return 'Élevée';
      case NotificationPriority.urgent:
        return 'Urgente';
    }
  }

  int get importance {
    switch (this) {
      case NotificationPriority.low:
        return 1;
      case NotificationPriority.normal:
        return 2;
      case NotificationPriority.high:
        return 3;
      case NotificationPriority.urgent:
        return 4;
    }
  }
}