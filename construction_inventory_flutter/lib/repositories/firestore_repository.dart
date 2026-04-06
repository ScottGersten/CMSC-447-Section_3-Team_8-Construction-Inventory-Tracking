import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';
import '../models/material.dart';
import '../models/delivery.dart';
import '../models/material_request.dart';
import '../models/app_user.dart';
import '../models/location.dart';
import '../models/purchase_order.dart';
import '../models/packing_slip_item.dart';
import '../models/logs.dart';
import '../models/project.dart';
import '../models/notification.dart';

/// Single access point for all Firestore operations.
class FirestoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Collection references ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _materials =>
      _db.collection('materials');
  CollectionReference<Map<String, dynamic>> get _inventoryItems =>
      _db.collection('inventoryItems');



  // =========================================================================
  // MATERIALS
  // =========================================================================

  Future<String> createMaterial(Material material) async {
    try {
      // Business rule: no duplicate names (SRS Section 3)
      final dup = await _materials
          .where('name', isEqualTo: material.name)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        throw Exception(
            'Material "${material.name}" already exists. Names must be unique.');
      }
      final ref = await _materials.add(material.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'materials',
          recordId: ref.id,
          newValue: material.name);
      return ref.id;
    } catch (e) {
      throw Exception('createMaterial failed: $e');
    }
  }

  Future<Material?> getMaterial(String materialId) async {
    final doc = await _materials.doc(materialId).get();
    return doc.exists ? Material.fromFirestore(doc) : null;
  }

  Stream<List<Material>> streamAllMaterials() =>
      _materials.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => Material.fromFirestore(d)).toList());

  // =========================================================================
  // INVENTORY ITEMS
  // =========================================================================

  Future<String> createInventoryItem(InventoryItem item) async {
    try {
      final ref = await _inventoryItems.add(item.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'inventoryItems',
          recordId: ref.id,
          newValue: 'materialId:${item.materialId}');
      return ref.id;
    } catch (e) {
      throw Exception('createInventoryItem failed: $e');
    }
  }

  Future<InventoryItem?> getInventoryItem(String itemId) async {
    final doc = await _inventoryItems.doc(itemId).get();
    return doc.exists ? InventoryItem.fromFirestore(doc) : null;
  }

  Stream<List<InventoryItem>> streamInventoryItems({String? locationId}) {
    Query<Map<String, dynamic>> q = _inventoryItems;
    if (locationId != null) q = q.where('locationId', isEqualTo: locationId);
    return q.snapshots().map(
        (s) => s.docs.map((d) => InventoryItem.fromFirestore(d)).toList());
  }

  /// Atomically adjusts quantity and recomputes status.
  /// Uses a Firestore transaction to handle concurrent writes safely (SRS 2.4.1).
  Future<void> updateQuantity({
    required String inventoryItemId,
    required double delta,
  }) async {
    try {
      await _db.runTransaction((tx) async {
        final ref = _inventoryItems.doc(inventoryItemId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Inventory item not found.');
        final current = InventoryItem.fromFirestore(snap);
        final newQty = current.quantity + delta;
        // Business rule: never below zero (SRS Section 3)
        if (newQty < 0) {
          throw Exception(
              'Insufficient stock: cannot subtract ${delta.abs()} from ${current.quantity}.');
        }
        tx.update(ref, {
          'quantity': newQty,
          'availableQuantity': newQty - current.reservedQuantity,
          'status': _statusStr(_deriveStatus(newQty, current.lowStockThreshold)),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
      await _writeAuditLog(
          action: 'Update',
          collection: 'inventoryItems',
          recordId: inventoryItemId,
          newValue: 'delta:$delta');
    } catch (e) {
      throw Exception('updateQuantity failed: $e');
    }
  }

  Future<void> updateInventoryLocation({
    required String inventoryItemId,
    required String newLocationId,
    required String oldLocationId,
  }) async {
    try {
      await _inventoryItems.doc(inventoryItemId).update({
        'locationId': newLocationId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      await _writeAuditLog(
          action: 'Update',
          collection: 'inventoryItems',
          recordId: inventoryItemId,
          oldValue: oldLocationId,
          newValue: newLocationId);
    } catch (e) {
      throw Exception('updateInventoryLocation failed: $e');
    }
  }

  // =========================================================================
  // USERS
  // =========================================================================

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<AppUser?> getUserByEmail(String email) async {
    final query = await _users.where('email', isEqualTo: email).limit(1).get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  Future<AppUser?> getUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  Stream<List<AppUser>> streamAllUsers() =>
      _users.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => AppUser.fromFirestore(d)).toList());

  Future<String> createUser(AppUser user) async {
    try {
      final dup = await _users
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        throw Exception('User with email "${user.email}" already exists.');
      }
      final ref = await _users.add(user.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'users',
          recordId: ref.id,
          newValue: '${user.name} (${user.role})');
      return ref.id;
    } catch (e) {
      throw Exception('createUser failed: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _users.doc(userId).delete();
      // Also delete associated credentials
      try {
        await _db.collection('userCredentials').doc(userId).delete();
      } catch (e) {
        print('Note: userCredentials not found for deleted user');
      }
      await _writeAuditLog(
          action: 'Delete',
          collection: 'users',
          recordId: userId,
          newValue: 'User deleted');
    } catch (e) {
      throw Exception('deleteUser failed: $e');
    }
  }

  // =========================================================================
  // PASSWORD CREDENTIALS
  // =========================================================================

  Future<String?> getPasswordHash(String userId) async {
    try {
      final doc = await _db.collection('userCredentials').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data()?['passwordHash'] as String?;
    } catch (e) {
      print('Error retrieving password hash: $e');
      return null;
    }
  }

  Future<void> setPasswordHash(String userId, String passwordHash) async {
    try {
      await _db.collection('userCredentials').doc(userId).set({
        'passwordHash': passwordHash,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to store password: $e');
    }
  }

  Future<void> updatePasswordHash(String userId, String newPasswordHash) async {
    try {
      await _db.collection('userCredentials').doc(userId).update({
        'passwordHash': newPasswordHash,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // =========================================================================
  // AUDIT LOGS
  // =========================================================================

  Future<void> _writeAuditLog({
    required String action,
    required String collection,
    required String recordId,
    String? oldValue,
    String? newValue,
  }) async {
    try {
      await _db.collection('auditLogs').add({
        'action': action,
        'collection': collection,
        'recordId': recordId,
        'oldValue': oldValue,
        'newValue': newValue,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log but don't throw - we don't want audit log failures to break the app
      print('Audit log failed: $e');
    }
  }

  // =========================================================================
  // INVENTORY STATUS HELPERS
  // =========================================================================

  /// Determine inventory status based on quantity and threshold.
  String _deriveStatus(double quantity, double threshold) {
    if (quantity <= 0) return 'outOfStock';
    if (quantity <= threshold) return 'lowStock';
    return 'inStock';
  }

  /// Convert status enum to string for storage.
  String _statusStr(String status) => status;
}
