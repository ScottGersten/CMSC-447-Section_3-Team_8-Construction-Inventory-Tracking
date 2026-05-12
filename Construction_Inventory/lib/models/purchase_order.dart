import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseOrderStatus { pending, partiallyFulfilled, fulfilled }

class PurchaseOrder {
  final String poId;
  final String poNumber; // human-readable reference
  final DateTime orderDate; // audit timestamp, immutable
  final DateTime expectedDeliveryDate;
  final PurchaseOrderStatus status;
  final String? pdfStoragePath; // set after PM uploads PDF (SRS 4.1.1)

  PurchaseOrder({
    required this.poId,
    required this.poNumber,
    required this.orderDate,
    required this.expectedDeliveryDate,
    required this.status,
    this.pdfStoragePath,
  });

  factory PurchaseOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      poId: doc.id,
      poNumber: data['poNumber'] as String,
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      expectedDeliveryDate:
          (data['expectedDeliveryDate'] as Timestamp).toDate(),
      status: _statusFromString(data['status'] as String),
      pdfStoragePath: data['pdfStoragePath'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poNumber': poNumber,
      'orderDate': FieldValue.serverTimestamp(), // immutable audit timestamp
      'expectedDeliveryDate': Timestamp.fromDate(expectedDeliveryDate),
      'status': _statusToString(status),
      if (pdfStoragePath != null) 'pdfStoragePath': pdfStoragePath,
    };
  }

  static PurchaseOrderStatus _statusFromString(String s) {
    switch (s) {
      case 'PartiallyFulfilled':
        return PurchaseOrderStatus.partiallyFulfilled;
      case 'Fulfilled':
        return PurchaseOrderStatus.fulfilled;
      default:
        return PurchaseOrderStatus.pending;
    }
  }

  static String _statusToString(PurchaseOrderStatus s) {
    switch (s) {
      case PurchaseOrderStatus.partiallyFulfilled:
        return 'PartiallyFulfilled';
      case PurchaseOrderStatus.fulfilled:
        return 'Fulfilled';
      default:
        return 'Pending';
    }
  }
}

class PurchaseOrderItem {
  final String poItemId;
  final String poId; // foreign key -> purchaseOrders
  final String materialId; // foreign key -> materials
  final double quantityOrdered; // must be > 0
  final double unitCost;

  PurchaseOrderItem({
    required this.poItemId,
    required this.poId,
    required this.materialId,
    required this.quantityOrdered,
    required this.unitCost,
  });

  factory PurchaseOrderItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseOrderItem(
      poItemId: doc.id,
      poId: data['poId'] as String,
      materialId: data['materialId'] as String,
      quantityOrdered: (data['quantityOrdered'] as num).toDouble(),
      unitCost: (data['unitCost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poId': poId,
      'materialId': materialId,
      'quantityOrdered': quantityOrdered,
      'unitCost': unitCost,
    };
  }
}