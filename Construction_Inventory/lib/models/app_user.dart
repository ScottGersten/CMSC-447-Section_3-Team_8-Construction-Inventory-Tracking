import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { fieldCrew, warehouseStaff, projectManager, systemAdmin }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? fcmToken;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.fcmToken,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['name'] as String,
      email: data['email'] as String,
      role: _roleFromString(data['role'] as String),
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': _roleToString(role),
      if (fcmToken != null) 'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static UserRole _roleFromString(String s) {
    switch (s) {
      case 'WarehouseStaff':
        return UserRole.warehouseStaff;
      case 'ProjectManager':
        return UserRole.projectManager;
      case 'SystemAdmin':
        return UserRole.systemAdmin;
      default:
        return UserRole.fieldCrew;
    }
  }

  static String _roleToString(UserRole r) {
    switch (r) {
      case UserRole.warehouseStaff:
        return 'WarehouseStaff';
      case UserRole.projectManager:
        return 'ProjectManager';
      case UserRole.systemAdmin:
        return 'SystemAdmin';
      default:
        return 'FieldCrew';
    }
  }
}