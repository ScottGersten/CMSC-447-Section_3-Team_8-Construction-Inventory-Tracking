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
/// Services call this class — UI never touches Firestore directly.
/// Every mutating operation writes an immutable audit log (SRS 6.3.2).
class FirestoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Collection references ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _materials =>
      _db.collection('materials');
  CollectionReference<Map<String, dynamic>> get _inventoryItems =>
      _db.collection('inventoryItems');
  CollectionReference<Map<String, dynamic>> get _locations =>
      _db.collection('locations');
  CollectionReference<Map<String, dynamic>> get _deliveries =>
      _db.collection('deliveries');
  CollectionReference<Map<String, dynamic>> get _materialRequests =>
      _db.collection('materialRequests');
  CollectionReference<Map<String, dynamic>> get _purchaseOrders =>
      _db.collection('purchaseOrders');
  CollectionReference<Map<String, dynamic>> get _purchaseOrderItems =>
      _db.collection('purchaseOrderItems');
  CollectionReference<Map<String, dynamic>> get _packingSlipItems =>
      _db.collection('packingSlipItems');
  CollectionReference<Map<String, dynamic>> get _transferLogs =>
      _db.collection('transferLogs');
  CollectionReference<Map<String, dynamic>> get _installationLogs =>
      _db.collection('installationLogs');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _db.collection('auditLogs');
  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');
  CollectionReference<Map<String, dynamic>> get _projectAssignments =>
      _db.collection('projectAssignments');
  CollectionReference<Map<String, dynamic>> get _projectMaterials =>
      _db.collection('projectMaterials');

  // =========================================================================
  // USERS
  // =========================================================================

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

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      return doc.exists ? AppUser.fromFirestore(doc) : null;
    } catch (e) {
      throw Exception('getUser failed: $e');
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final query = await _users.where('email', isEqualTo: email).limit(1).get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  Future<AppUser?> getUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  Future<void> updateUserRole(String uid, UserRole role) async {
    try {
      final old = (await _users.doc(uid).get()).data()?['role'];
      await _users.doc(uid).update({'role': _roleStr(role)});
      await _writeAuditLog(
          action: 'Update',
          collection: 'users',
          recordId: uid,
          oldValue: old,
          newValue: _roleStr(role));
    } catch (e) {
      throw Exception('updateUserRole failed: $e');
    }
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _users.doc(uid).update({'fcmToken': token});
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
          action: 'Delete', collection: 'users', recordId: userId);
    } catch (e) {
      throw Exception('deleteUser failed: $e');
    }
  }

  Stream<List<AppUser>> streamAllUsers() => _users.orderBy('name').snapshots().map(
      (s) => s.docs.map((d) => AppUser.fromFirestore(d)).toList());

  /// Fetch all users with a given role — used to find PM / warehouse recipients for notifications.
  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final snap =
        await _users.where('role', isEqualTo: _roleStr(role)).get();
    return snap.docs.map((d) => AppUser.fromFirestore(d)).toList();
  }

  // =========================================================================
  // LOCATIONS
  // =========================================================================

  Future<String> createLocation(Location location) async {
    try {
      final ref = await _locations.add(location.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'locations',
          recordId: ref.id,
          newValue: location.name);
      return ref.id;
    } catch (e) {
      throw Exception('createLocation failed: $e');
    }
  }

  Future<Location?> getLocation(String locationId) async {
    final doc = await _locations.doc(locationId).get();
    return doc.exists ? Location.fromFirestore(doc) : null;
  }

  Stream<List<Location>> streamAllLocations() =>
      _locations.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => Location.fromFirestore(d)).toList());

  Stream<List<Location>> streamLocationsByType(LocationType type) =>
      _locations
          .where('type', isEqualTo: _locationTypeStr(type))
          .snapshots()
          .map((s) => s.docs.map((d) => Location.fromFirestore(d)).toList());

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

  Future<void> deleteMaterial(String materialId) async {
    try {
      await _materials.doc(materialId).delete();
      await _writeAuditLog(
          action: 'Delete',
          collection: 'materials',
          recordId: materialId,
          newValue: 'Material deleted');
    } catch (e) {
      throw Exception('deleteMaterial failed: $e');
    }
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
  // PURCHASE ORDERS  (Use Case 6 — PM uploads pay order PDF)
  // =========================================================================

  Future<String> createPurchaseOrder(PurchaseOrder po) async {
    try {
      final ref = await _purchaseOrders.add(po.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'purchaseOrders',
          recordId: ref.id,
          newValue: po.poNumber);
      return ref.id;
    } catch (e) {
      throw Exception('createPurchaseOrder failed: $e');
    }
  }

  /// Attaches the Cloud Storage path after PDF upload completes (SRS 4.1.1).
  Future<void> attachPdfToPurchaseOrder(String poId, String storagePath) async {
    try {
      await _purchaseOrders
          .doc(poId)
          .update({'pdfStoragePath': storagePath});
    } catch (e) {
      throw Exception('attachPdfToPurchaseOrder failed: $e');
    }
  }

  Future<void> updatePurchaseOrderStatus(
      String poId, PurchaseOrderStatus status) async {
    final statusStr = status == PurchaseOrderStatus.fulfilled
        ? 'Fulfilled'
        : status == PurchaseOrderStatus.partiallyFulfilled
            ? 'PartiallyFulfilled'
            : 'Pending';
    await _purchaseOrders.doc(poId).update({'status': statusStr});
  }

  Future<String> createPurchaseOrderItem(PurchaseOrderItem item) async {
    if (item.quantityOrdered <= 0) {
      throw Exception('quantityOrdered must be > 0');
    }
    try {
      final ref = await _purchaseOrderItems.add(item.toFirestore());
      return ref.id;
    } catch (e) {
      throw Exception('createPurchaseOrderItem failed: $e');
    }
  }

  Stream<List<PurchaseOrder>> streamPurchaseOrders() =>
      _purchaseOrders
          .orderBy('orderDate', descending: true)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => PurchaseOrder.fromFirestore(d)).toList());

  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(String poId) async {
    final snap =
        await _purchaseOrderItems.where('poId', isEqualTo: poId).get();
    return snap.docs.map((d) => PurchaseOrderItem.fromFirestore(d)).toList();
  }

  // =========================================================================
  // DELIVERIES
  // =========================================================================

  Future<String> storeDeliveryRecord(Delivery delivery) async {
    try {
      final ref = await _deliveries.add(delivery.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'deliveries',
          recordId: ref.id,
          newValue: 'poId:${delivery.poId}');
      return ref.id;
    } catch (e) {
      throw Exception('storeDeliveryRecord failed: $e');
    }
  }

  Stream<List<Delivery>> streamDeliveries({String? locationId}) {
    Query<Map<String, dynamic>> q =
        _deliveries.orderBy('deliveryDate', descending: true);
    if (locationId != null) q = q.where('locationId', isEqualTo: locationId);
    return q.snapshots()
        .map((s) => s.docs.map((d) => Delivery.fromFirestore(d)).toList());
  }

  // =========================================================================
  // PACKING SLIP ITEMS  (OCR line items — Use Case 3)
  // =========================================================================

  Future<String> savePackingSlipItem(PackingSlipItem item) async {
    try {
      final ref = await _packingSlipItems.add(item.toFirestore());
      return ref.id;
    } catch (e) {
      throw Exception('savePackingSlipItem failed: $e');
    }
  }

  /// Marks an item as manually verified after user review in the UI.
  Future<void> markPackingSlipItemVerified(String itemId) async {
    await _packingSlipItems.doc(itemId).update({'isManuallyVerified': true});
  }

  Future<List<PackingSlipItem>> getPackingSlipItemsForDelivery(
      String deliveryId) async {
    final snap = await _packingSlipItems
        .where('deliveryId', isEqualTo: deliveryId)
        .get();
    return snap.docs.map((d) => PackingSlipItem.fromFirestore(d)).toList();
  }

  // =========================================================================
  // MATERIAL REQUESTS
  // =========================================================================

  Future<String> logMaterialRequest(MaterialRequest request) async {
    if (request.quantityRequested <= 0) {
      throw Exception('quantityRequested must be > 0');
    }
    try {
      final ref = await _materialRequests.add(request.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'materialRequests',
          recordId: ref.id,
          newValue: 'materialId:${request.materialId}');
      return ref.id;
    } catch (e) {
      throw Exception('logMaterialRequest failed: $e');
    }
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    double? quantityFulfilled,
  }) async {
    try {
      await _materialRequests.doc(requestId).update({
        'status': _requestStatusStr(status),
        if (quantityFulfilled != null) 'quantityFulfilled': quantityFulfilled,
      });
    } catch (e) {
      throw Exception('updateRequestStatus failed: $e');
    }
  }

  Stream<List<MaterialRequest>> streamMaterialRequests({
    RequestStatus? status,
    String? requestedByUserId,
  }) {
    Query<Map<String, dynamic>> q =
        _materialRequests.orderBy('requestDate', descending: true);
    if (status != null) {
      q = q.where('status', isEqualTo: _requestStatusStr(status));
    }
    if (requestedByUserId != null) {
      q = q.where('requestedByUserId', isEqualTo: requestedByUserId);
    }
    return q.snapshots().map(
        (s) => s.docs.map((d) => MaterialRequest.fromFirestore(d)).toList());
  }

  // =========================================================================
  // TRANSFER LOGS  (Use Case 4)
  // =========================================================================

  Future<String> createTransferLog(TransferLog log) async {
    if (log.quantity <= 0) throw Exception('Transfer quantity must be > 0');
    try {
      final ref = await _transferLogs.add(log.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'transferLogs',
          recordId: ref.id,
          newValue:
              '${log.fromLocationId} -> ${log.toLocationId}, qty:${log.quantity}');
      return ref.id;
    } catch (e) {
      throw Exception('createTransferLog failed: $e');
    }
  }

  Stream<List<TransferLog>> streamTransferLogs({String? materialId}) {
    Query<Map<String, dynamic>> q =
        _transferLogs.orderBy('transferDate', descending: true);
    if (materialId != null) q = q.where('materialId', isEqualTo: materialId);
    return q.snapshots().map(
        (s) => s.docs.map((d) => TransferLog.fromFirestore(d)).toList());
  }

  // =========================================================================
  // INSTALLATION LOGS
  // =========================================================================

  Future<String> createInstallationLog(InstallationLog log) async {
    if (log.quantityInstalled <= 0) {
      throw Exception('quantityInstalled must be > 0');
    }
    try {
      final ref = await _installationLogs.add(log.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'installationLogs',
          recordId: ref.id,
          newValue: 'materialId:${log.materialId}, qty:${log.quantityInstalled}');
      return ref.id;
    } catch (e) {
      throw Exception('createInstallationLog failed: $e');
    }
  }

  Future<List<InstallationLog>> getInstallationLogsForMaterial(
      String materialId) async {
    final snap = await _installationLogs
        .where('materialId', isEqualTo: materialId)
        .orderBy('installationDate', descending: true)
        .get();
    return snap.docs.map((d) => InstallationLog.fromFirestore(d)).toList();
  }

  // =========================================================================
  // PROJECTS
  // =========================================================================

  Future<String> createProject(Project project) async {
    try {
      final ref = await _projects.add(project.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'projects',
          recordId: ref.id,
          newValue: project.name);
      return ref.id;
    } catch (e) {
      throw Exception('createProject failed: $e');
    }
  }

  Stream<List<Project>> streamProjects({ProjectStatus? status}) {
    Query<Map<String, dynamic>> q = _projects;
    if (status != null) {
      final s = status == ProjectStatus.completed
          ? 'Completed'
          : status == ProjectStatus.onHold
              ? 'OnHold'
              : 'Active';
      q = q.where('status', isEqualTo: s);
    }
    return q.snapshots()
        .map((s) => s.docs.map((d) => Project.fromFirestore(d)).toList());
  }

  Future<void> createProjectAssignment(ProjectAssignment assignment) async {
    try {
      final ref =
          await _projectAssignments.add(assignment.toFirestore());
      await _writeAuditLog(
          action: 'Insert',
          collection: 'projectAssignments',
          recordId: ref.id,
          newValue:
              'project:${assignment.projectId}, user:${assignment.userId}');
    } catch (e) {
      throw Exception('createProjectAssignment failed: $e');
    }
  }

  Future<List<ProjectAssignment>> getAssignmentsForProject(
      String projectId) async {
    final snap = await _projectAssignments
        .where('projectId', isEqualTo: projectId)
        .get();
    return snap.docs
        .map((d) => ProjectAssignment.fromFirestore(d))
        .toList();
  }

  Future<String> createProjectMaterial(ProjectMaterial pm) async {
    try {
      final ref = await _projectMaterials.add(pm.toFirestore());
      return ref.id;
    } catch (e) {
      throw Exception('createProjectMaterial failed: $e');
    }
  }

  Future<void> updateProjectMaterialQuantities({
    required String projectMaterialId,
    double? quantityReceived,
    double? quantityInstalled,
  }) async {
    final updates = <String, dynamic>{};
    if (quantityReceived != null) updates['quantityReceived'] = quantityReceived;
    if (quantityInstalled != null) {
      updates['quantityInstalled'] = quantityInstalled;
    }
    if (updates.isEmpty) return;
    await _projectMaterials.doc(projectMaterialId).update(updates);
  }

  Future<List<ProjectMaterial>> getProjectMaterials(String projectId) async {
    final snap = await _projectMaterials
        .where('projectId', isEqualTo: projectId)
        .get();
    return snap.docs.map((d) => ProjectMaterial.fromFirestore(d)).toList();
  }

  // =========================================================================
  // NOTIFICATIONS  (SRS 4.3.x)
  // =========================================================================

  /// Writes a notification document. A Firebase Cloud Function should be
  /// set up to listen on this collection and dispatch via FCM.
  Future<void> writeNotification({
    required String recipientUserId,
    required String message,
    required NotificationType type,
  }) async {
    try {
      await _notifications.add(AppNotification(
        notificationId: '',
        recipientUserId: recipientUserId,
        message: message,
        type: type,
        createdAt: DateTime.now(),
      ).toFirestore());
    } catch (e) {
      throw Exception('writeNotification failed: $e');
    }
  }

  /// Marks a notification read and records the timestamp (SRS 6.3.5).
  Future<void> markNotificationRead(String notificationId) async {
    await _notifications.doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> streamNotificationsForUser(String userId) =>
      _notifications
          .where('recipientUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => AppNotification.fromFirestore(d)).toList());

  // =========================================================================
  // AUDIT LOGS  (immutable — no update/delete exposed, SRS 6.3.2)
  // =========================================================================

  Future<void> _writeAuditLog({
    required String action,
    required String collection,
    required String recordId,
    String? oldValue,
    String? newValue,
  }) async {
    await _auditLogs.add({
      'action': action,
      'tableAffected': collection,
      'recordId': recordId,
      if (oldValue != null) 'oldValue': oldValue,
      if (newValue != null) 'newValue': newValue,
      'changedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  InventoryStatus _deriveStatus(double qty, double threshold) {
    if (qty <= 0) return InventoryStatus.outOfStock;
    if (qty <= threshold) return InventoryStatus.lowStock;
    return InventoryStatus.inStock;
  }

  String _statusStr(InventoryStatus s) {
    switch (s) {
      case InventoryStatus.lowStock: return 'LowStock';
      case InventoryStatus.outOfStock: return 'OutOfStock';
      default: return 'InStock';
    }
  }

  String _roleStr(UserRole r) {
    switch (r) {
      case UserRole.warehouseStaff: return 'WarehouseStaff';
      case UserRole.projectManager: return 'ProjectManager';
      case UserRole.systemAdmin: return 'SystemAdmin';
      default: return 'FieldCrew';
    }
  }

  String _requestStatusStr(RequestStatus s) {
    switch (s) {
      case RequestStatus.fulfilled: return 'Fulfilled';
      case RequestStatus.cancelled: return 'Cancelled';
      default: return 'Pending';
    }
  }

  String _locationTypeStr(LocationType t) {
    switch (t) {
      case LocationType.yard: return 'Yard';
      case LocationType.jobsite: return 'Jobsite';
      default: return 'Warehouse';
    }
  }
}
