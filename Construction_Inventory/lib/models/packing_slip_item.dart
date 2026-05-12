import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single line item parsed from a packing slip via ML Kit OCR.
/// Low confidence scores (ParsedConfidenceScore) trigger manual review in the UI.
class PackingSlipItem {
  final String packingSlipItemId;
  final String deliveryId; // foreign key -> deliveries
  final String rawDescription; // unprocessed OCR text
  final double quantityListed;
  final String unitOfMeasure;
  final double parsedConfidenceScore; // 0.0–1.0; low = manual review required
  final bool isManuallyVerified; // set true when user confirms in review form

  PackingSlipItem({
    required this.packingSlipItemId,
    required this.deliveryId,
    required this.rawDescription,
    required this.quantityListed,
    required this.unitOfMeasure,
    required this.parsedConfidenceScore,
    this.isManuallyVerified = false,
  });

  factory PackingSlipItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PackingSlipItem(
      packingSlipItemId: doc.id,
      deliveryId: data['deliveryId'] as String,
      rawDescription: data['rawDescription'] as String,
      quantityListed: (data['quantityListed'] as num).toDouble(),
      unitOfMeasure: data['unitOfMeasure'] as String,
      parsedConfidenceScore:
          (data['parsedConfidenceScore'] as num).toDouble(),
      isManuallyVerified: data['isManuallyVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deliveryId': deliveryId,
      'rawDescription': rawDescription,
      'quantityListed': quantityListed,
      'unitOfMeasure': unitOfMeasure,
      'parsedConfidenceScore': parsedConfidenceScore,
      'isManuallyVerified': isManuallyVerified,
    };
  }

  /// Returns true when the confidence is low enough to require human review.
  bool get requiresReview => parsedConfidenceScore < 0.75;

  PackingSlipItem copyWithVerified() {
    return PackingSlipItem(
      packingSlipItemId: packingSlipItemId,
      deliveryId: deliveryId,
      rawDescription: rawDescription,
      quantityListed: quantityListed,
      unitOfMeasure: unitOfMeasure,
      parsedConfidenceScore: parsedConfidenceScore,
      isManuallyVerified: true,
    );
  }
}