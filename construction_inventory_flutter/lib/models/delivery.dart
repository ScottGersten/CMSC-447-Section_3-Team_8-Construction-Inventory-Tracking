import 'package:cloud_firestore/cloud_firestore.dart';

class Delivery {
  final String deliveryId;
  final String poId;
  final String locationId;
  final String loggedByUserId;
  final DateTime deliveryDate; // audit timestamp, immutable
  final DateTime actualArrivalTime;
  final String? notes;
  final String photoStoragePath; // immutable after confirmation per SRS 6.3.4

  Delivery({
    required this.deliveryId,
    required this.poId,
    required this.locationId,
    required this.loggedByUserId,
    required this.deliveryDate,
    required this.actualArrivalTime,
    this.notes,
    required this.photoStoragePath,
  });

  factory Delivery.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Delivery(
      deliveryId: doc.id,
      poId: data['poId'] as String,
      locationId: data['locationId'] as String,
      loggedByUserId: data['loggedByUserId'] as String,
      deliveryDate: (data['deliveryDate'] as Timestamp).toDate(),
      actualArrivalTime: (data['actualArrivalTime'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
      photoStoragePath: data['photoStoragePath'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poId': poId,
      'locationId': locationId,
      'loggedByUserId': loggedByUserId,
      'deliveryDate': FieldValue.serverTimestamp(), // immutable audit timestamp
      'actualArrivalTime': Timestamp.fromDate(actualArrivalTime),
      if (notes != null) 'notes': notes,
      'photoStoragePath': photoStoragePath,
    };
  }
}