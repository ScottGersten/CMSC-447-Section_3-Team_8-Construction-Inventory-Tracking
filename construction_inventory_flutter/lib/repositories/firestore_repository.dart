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
