import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, fulfilled, cancelled }

class MaterialRequest {
  final String requestId;
  final String requestedByUserId;
  final String materialId;
  final String locationId; // destination jobsite
  final double quantityRequested;
  final double quantityFulfilled;
  final RequestStatus status;
  final DateTime requestDate;
  final DateTime? requiredByDate;
  final String? notes;

  MaterialRequest({
    required this.requestId,
    required this.requestedByUserId,
    required this.materialId,
    required this.locationId,
    required this.quantityRequested,
    this.quantityFulfilled = 0.0,
    required this.status,
    required this.requestDate,
    this.requiredByDate,
    this.notes,
  });

  factory MaterialRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialRequest(
      requestId: doc.id,
      requestedByUserId: data['requestedByUserId'] as String,
      materialId: data['materialId'] as String,
      locationId: data['locationId'] as String,
      quantityRequested: (data['quantityRequested'] as num).toDouble(),
      quantityFulfilled: (data['quantityFulfilled'] as num? ?? 0).toDouble(),
      status: _statusFromString(data['status'] as String),
      requestDate: (data['requestDate'] as Timestamp).toDate(),
      requiredByDate: data['requiredByDate'] != null
          ? (data['requiredByDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestedByUserId': requestedByUserId,
      'materialId': materialId,
      'locationId': locationId,
      'quantityRequested': quantityRequested,
      'quantityFulfilled': quantityFulfilled,
      'status': _statusToString(status),
      'requestDate': FieldValue.serverTimestamp(),
      if (requiredByDate != null)
        'requiredByDate': Timestamp.fromDate(requiredByDate!),
      if (notes != null) 'notes': notes,
    };
  }

  static RequestStatus _statusFromString(String s) {
    switch (s) {
      case 'Fulfilled':
        return RequestStatus.fulfilled;
      case 'Cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pending;
    }
  }

  static String _statusToString(RequestStatus s) {
    switch (s) {
      case RequestStatus.fulfilled:
        return 'Fulfilled';
      case RequestStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}