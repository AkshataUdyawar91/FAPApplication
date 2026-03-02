import 'package:equatable/equatable.dart';

class ConfidenceScore extends Equatable {
  final String id;
  final String packageId;
  final double overallConfidence;
  final double poConfidence;
  final double invoiceConfidence;
  final double costSummaryConfidence;
  final double activityConfidence;
  final double photoConfidence;
  final bool requiresReview;

  const ConfidenceScore({
    required this.id,
    required this.packageId,
    required this.overallConfidence,
    required this.poConfidence,
    required this.invoiceConfidence,
    required this.costSummaryConfidence,
    required this.activityConfidence,
    required this.photoConfidence,
    required this.requiresReview,
  });

  @override
  List<Object?> get props => [
        id,
        packageId,
        overallConfidence,
        poConfidence,
        invoiceConfidence,
        costSummaryConfidence,
        activityConfidence,
        photoConfidence,
        requiresReview,
      ];
}
