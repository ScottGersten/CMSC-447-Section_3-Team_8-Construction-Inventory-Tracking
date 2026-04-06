import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryStatus { inStock, lowStock, outOfStock }

class InventoryItem {
  final String inventoryItemId;
  final String materialId;
  final String locationId;
  final double quantity;
  final double reservedQuantity;
  final double availableQuantity; // computed: quantity - reservedQuantity
  final double lowStockThreshold;
  final InventoryStatus status;
  final DateTime lastUpdatedAt;

  InventoryItem({
    required this.inventoryItemId,
    required this.materialId,
    required this.locationId,
    required this.quantity,
    required this.reservedQuantity,
    required this.lowStockThreshold,
    required this.status,
    required this.lastUpdatedAt,
  }) : availableQuantity = quantity - reservedQuantity;

  /// Construct from a Firestore document snapshot.
  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      inventoryItemId: doc.id,
      materialId: data['materialId'] as String,
      locationId: data['locationId'] as String,
      quantity: (data['quantity'] as num).toDouble(),
      reservedQuantity: (data['reservedQuantity'] as num? ?? 0).toDouble(),
      lowStockThreshold: (data['lowStockThreshold'] as num).toDouble(),
      status: _statusFromString(data['status'] as String),
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp).toDate(),
    );
  }

  /// Serialize to a map for Firestore writes.
  Map<String, dynamic> toFirestore() {
    return {
      'materialId': materialId,
      'locationId': locationId,
      'quantity': quantity,
      'reservedQuantity': reservedQuantity,
      'availableQuantity': availableQuantity,
      'lowStockThreshold': lowStockThreshold,
      'status': _statusToString(status),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Returns a copy with updated fields — use when adjusting quantity.
  InventoryItem copyWith({
    double? quantity,
    double? reservedQuantity,
    double? lowStockThreshold,
    InventoryStatus? status,
  }) {
    return InventoryItem(
      inventoryItemId: inventoryItemId,
      materialId: materialId,
      locationId: locationId,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      status: status ?? this.status,
      lastUpdatedAt: DateTime.now(),
    );
  }

  static InventoryStatus _statusFromString(String s) {
    switch (s) {
      case 'LowStock':
        return InventoryStatus.lowStock;
      case 'OutOfStock':
        return InventoryStatus.outOfStock;
      default:
        return InventoryStatus.inStock;
    }
  }

  static String _statusToString(InventoryStatus s) {
    switch (s) {
      case InventoryStatus.lowStock:
        return 'LowStock';
      case InventoryStatus.outOfStock:
        return 'OutOfStock';
      default:
        return 'InStock';
    }
  }
}