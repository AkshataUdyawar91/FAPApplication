import '../../domain/entities/confidence_score.dart';

class ConfidenceScoreModel extends ConfidenceScore {
  const ConfidenceScoreModel({
    required super.id,
    required super.packageId,
    required super.overallConfidence,
    required super.poConfidence,
    required super.invoiceConfidence,
    required super.costSummaryConfidence,
    required super.activityConfidence,
    required super.photoConfidence,
    required super.requiresReview,
  });

  factory ConfidenceScoreModel.fromJson(Map<String, dynamic> json) {
    return ConfidenceScoreModel(
      id: json['id'] as String,
      packageId: json['packageId'] as String,
      overallConfidence: (json['overallConfidence'] as num).toDouble(),
      poConfidence: (json['poConfidence'] as num).toDouble(),
      invoiceConfidence: (json['invoiceConfidence'] as num).toDouble(),
      costSummaryConfidence: (json['costSummaryConfidence'] as num).toDouble(),
      activityConfidence: (json['activityConfidence'] as num).toDouble(),
      photoConfidence: (json['photoConfidence'] as num).toDouble(),
      requiresReview: json['requiresReview'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageId': packageId,
      'overallConfidence': overallConfidence,
      'poConfidence': poConfidence,
      'invoiceConfidence': invoiceConfidence,
      'costSummaryConfidence': costSummaryConfidence,
      'activityConfidence': activityConfidence,
      'photoConfidence': photoConfidence,
      'requiresReview': requiresReview,
    };
  }
}
