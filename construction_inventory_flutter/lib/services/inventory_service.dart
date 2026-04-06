import '../models/inventory_item.dart';
import '../models/delivery.dart';
import '../models/material_request.dart';
import '../models/notification.dart';
import '../repositories/firestore_repository.dart';

/// Central business-logic controller for Use Cases 1–4 and 9.
/// The UI calls these methods; this service decides what repository
/// operations to chain and in what order.
class InventoryService {
  final FirestoreRepository _repo;

  InventoryService(this._repo);

  // ─── Use Case 3: Log Delivery & Update Inventory ──────────────────────────

  /// Called after the user confirms OCR-parsed packing slip data.
  /// 1. Stores the delivery record.
  /// 2. Increments the matching inventory item.
  /// 3. Checks low-stock threshold and fires a notification if needed.
  Future<void> logDeliveryAndUpdateInventory({
    required Delivery delivery,
    required String inventoryItemId,
    required double quantityReceived,
    required List<String> projectManagerUserIds,
  }) async {
    // Store the delivery document first so we have an audit trail
    // even if the quantity update fails.
    await _repo.storeDeliveryRecord(delivery);

    // Update inventory quantity atomically (transaction in repository).
    await _repo.updateQuantity(
      inventoryItemId: inventoryItemId,
      delta: quantityReceived,
    );

    // Notify all project managers that a delivery was logged (SRS 4.3.1).
    for (final uid in projectManagerUserIds) {
      await _repo.writeNotification(
        recipientUserId: uid,
        message:
            'Delivery logged: $quantityReceived units received at location ${delivery.locationId}.',
        type: NotificationType.deliveryLogged,
      );
    }

    // Re-fetch updated item to check low-stock status (SRS 4.3.3).
    final updated = await _repo.getInventoryItem(inventoryItemId);
    if (updated == null) return;

    if (updated.status == InventoryStatus.lowStock) {
      for (final uid in projectManagerUserIds) {
        await _repo.writeNotification(
          recipientUserId: uid,
          message:
              'Low stock alert: inventory item $inventoryItemId is at ${updated.quantity} units.',
          type: NotificationType.lowStock,
        );
      }
    }

    if (updated.status == InventoryStatus.outOfStock) {
      for (final uid in projectManagerUserIds) {
        await _repo.writeNotification(
          recipientUserId: uid,
          message:
              'Out of stock: inventory item $inventoryItemId has reached zero.',
          type: NotificationType.outOfStock,
        );
      }
    }
  }

  // ─── Use Case 1: Request Material ─────────────────────────────────────────

  /// Field crew submits a material request.
  /// Validates quantity, logs the request, and notifies warehouse staff.
  Future<String> submitMaterialRequest({
    required MaterialRequest request,
    required List<String> warehouseStaffUserIds,
  }) async {
    // Business rule: quantity > 0 enforced in repository, but validate here
    // for a user-friendly message before any network call.
    if (request.quantityRequested <= 0) {
      throw Exception('Please enter a quantity greater than zero.');
    }

    final requestId = await _repo.logMaterialRequest(request);

    // Notify all warehouse staff (SRS 4.3.3).
    for (final uid in warehouseStaffUserIds) {
      await _repo.writeNotification(
        recipientUserId: uid,
        message:
            'New material request: ${request.quantityRequested} units of material '
            '${request.materialId} needed at location ${request.locationId}.',
        type: NotificationType.materialRequested,
      );
    }

    return requestId;
  }

  // ─── Use Case 2: Confirm Material Receipt ─────────────────────────────────

  /// Field crew confirms physical receipt of a previously fulfilled request.
  Future<void> confirmMaterialReceipt({
    required String requestId,
    required double quantityFulfilled,
  }) async {
    await _repo.updateRequestStatus(
      requestId: requestId,
      status: RequestStatus.fulfilled,
      quantityFulfilled: quantityFulfilled,
    );
  }

  // ─── Use Case 4: Transfer Material Between Locations ──────────────────────

  Future<void> transferMaterial({
    required String inventoryItemId,
    required String fromLocationId,
    required String toLocationId,
  }) async {
    await _repo.updateInventoryLocation(
      inventoryItemId: inventoryItemId,
      newLocationId: toLocationId,
      oldLocationId: fromLocationId,
    );
  }

  // ─── Use Case 9: View Material Availability ───────────────────────────────

  /// Returns a real-time stream for the inventory dashboard.
  Stream<List<InventoryItem>> watchInventory({String? locationId}) {
    return _repo.streamInventoryItems(locationId: locationId);
  }
}