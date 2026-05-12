import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit record created whenever a material is moved between locations (Use Case 4).
class TransferLog {
  final String transferId;
  final String inventoryItemId; // foreign key -> inventoryItems
  final String materialId; // foreign key -> materials
  final String fromLocationId; // foreign key -> locations
  final String toLocationId; // foreign key -> locations
  final String transferredByUserId; // foreign key -> users
  final double quantity; // must be > 0
  final DateTime transferDate;
  final String? reason;
  final String? notes;

  TransferLog({
    required this.transferId,
    required this.inventoryItemId,
    required this.materialId,
    required this.fromLocationId,
    required this.toLocationId,
    required this.transferredByUserId,
    required this.quantity,
    required this.transferDate,
    this.reason,
    this.notes,
  });

  factory TransferLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransferLog(
      transferId: doc.id,
      inventoryItemId: data['inventoryItemId'] as String,
      materialId: data['materialId'] as String,
      fromLocationId: data['fromLocationId'] as String,
      toLocationId: data['toLocationId'] as String,
      transferredByUserId: data['transferredByUserId'] as String,
      quantity: (data['quantity'] as num).toDouble(),
      transferDate: (data['transferDate'] as Timestamp).toDate(),
      reason: data['reason'] as String?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'inventoryItemId': inventoryItemId,
      'materialId': materialId,
      'fromLocationId': fromLocationId,
      'toLocationId': toLocationId,
      'transferredByUserId': transferredByUserId,
      'quantity': quantity,
      'transferDate': FieldValue.serverTimestamp(),
      if (reason != null) 'reason': reason,
      if (notes != null) 'notes': notes,
    };
  }
}

/// Records when field crew marks materials as physically installed on a jobsite.
class InstallationLog {
  final String installationId;
  final String inventoryItemId; // foreign key -> inventoryItems
  final String materialId; // foreign key -> materials
  final String locationId; // jobsite where installed
  final String installedByUserId; // foreign key -> users (field crew)
  final double quantityInstalled; // must be > 0
  final DateTime installationDate;
  final String? notes;

  InstallationLog({
    required this.installationId,
    required this.inventoryItemId,
    required this.materialId,
    required this.locationId,
    required this.installedByUserId,
    required this.quantityInstalled,
    required this.installationDate,
    this.notes,
  });

  factory InstallationLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstallationLog(
      installationId: doc.id,
      inventoryItemId: data['inventoryItemId'] as String,
      materialId: data['materialId'] as String,
      locationId: data['locationId'] as String,
      installedByUserId: data['installedByUserId'] as String,
      quantityInstalled: (data['quantityInstalled'] as num).toDouble(),
      installationDate: (data['installationDate'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'inventoryItemId': inventoryItemId,
      'materialId': materialId,
      'locationId': locationId,
      'installedByUserId': installedByUserId,
      'quantityInstalled': quantityInstalled,
      'installationDate': FieldValue.serverTimestamp(),
      if (notes != null) 'notes': notes,
    };
  }
}