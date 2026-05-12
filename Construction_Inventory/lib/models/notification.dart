import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  lowStock,
  outOfStock,
  requestFulfilled,
  deliveryLogged,
  materialRequested,
  userCreated,
}

class AppNotification {
  final String notificationId;
  final String recipientUserId; // foreign key -> users
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt; // null until opened (SRS 6.3.5)

  AppNotification({
    required this.notificationId,
    required this.recipientUserId,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      notificationId: doc.id,
      recipientUserId: data['recipientUserId'] as String,
      message: data['message'] as String,
      type: _typeFromString(data['type'] as String),
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipientUserId': recipientUserId,
      'message': message,
      'type': _typeToString(type),
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    };
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'LowStock':
        return NotificationType.lowStock;
      case 'OutOfStock':
        return NotificationType.outOfStock;
      case 'RequestFulfilled':
        return NotificationType.requestFulfilled;
      case 'DeliveryLogged':
        return NotificationType.deliveryLogged;
      case 'MaterialRequested':
        return NotificationType.materialRequested;
      case 'UserCreated':
        return NotificationType.userCreated;
      default:
        return NotificationType.deliveryLogged;
    }
  }

  static String _typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.lowStock:
        return 'LowStock';
      case NotificationType.outOfStock:
        return 'OutOfStock';
      case NotificationType.requestFulfilled:
        return 'RequestFulfilled';
      case NotificationType.deliveryLogged:
        return 'DeliveryLogged';
      case NotificationType.materialRequested:
        return 'MaterialRequested';
      case NotificationType.userCreated:
        return 'UserCreated';
    }
  }
}