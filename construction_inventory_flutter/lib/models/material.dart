import 'package:cloud_firestore/cloud_firestore.dart';

enum MaterialCategory { materials, equipment }

class Material {
  final String materialId;
  final String name;
  final String? description;
  final MaterialCategory category;
  final String? partNumber;
  final String? manufacturer;
  final String unitOfMeasure;
  final double unitCost;

  Material({
    required this.materialId,
    required this.name,
    this.description,
    required this.category,
    this.partNumber,
    this.manufacturer,
    required this.unitOfMeasure,
    this.unitCost = 0.0,
  });

  factory Material.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Material(
      materialId: doc.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      category: data['category'] == 'Equipment'
          ? MaterialCategory.equipment
          : MaterialCategory.materials,
      partNumber: data['partNumber'] as String?,
      manufacturer: data['manufacturer'] as String?,
      unitOfMeasure: data['unitOfMeasure'] as String,
      unitCost: (data['unitCost'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'category':
          category == MaterialCategory.equipment ? 'Equipment' : 'Materials',
      if (partNumber != null) 'partNumber': partNumber,
      if (manufacturer != null) 'manufacturer': manufacturer,
      'unitOfMeasure': unitOfMeasure,
      'unitCost': unitCost,
    };
  }
}