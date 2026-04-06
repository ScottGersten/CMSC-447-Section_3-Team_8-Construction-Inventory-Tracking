import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationType { warehouse, yard, jobsite }

class Location {
  final String locationId;
  final String name;
  final LocationType type;
  final String? address;
  final String? notes;

  Location({
    required this.locationId,
    required this.name,
    required this.type,
    this.address,
    this.notes,
  });

  factory Location.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Location(
      locationId: doc.id,
      name: data['name'] as String,
      type: _typeFromString(data['type'] as String),
      address: data['address'] as String?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': _typeToString(type),
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
    };
  }

  static LocationType _typeFromString(String s) {
    switch (s) {
      case 'Yard':
        return LocationType.yard;
      case 'Jobsite':
        return LocationType.jobsite;
      default:
        return LocationType.warehouse;
    }
  }

  static String _typeToString(LocationType t) {
    switch (t) {
      case LocationType.yard:
        return 'Yard';
      case LocationType.jobsite:
        return 'Jobsite';
      default:
        return 'Warehouse';
    }
  }
}