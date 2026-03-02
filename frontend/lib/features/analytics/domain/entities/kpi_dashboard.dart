import 'package:equatable/equatable.dart';

class KPIDashboard extends Equatable {
  final int totalSubmissions;
  final double approvalRate;
  final double avgProcessingTimeHours;
  final double autoApprovalRate;
  final Map<String, int> confidenceDistribution;
  final String aiNarrative;

  const KPIDashboard({
    required this.totalSubmissions,
    required this.approvalRate,
    required this.avgProcessingTimeHours,
    required this.autoApprovalRate,
    required this.confidenceDistribution,
    required this.aiNarrative,
  });

  @override
  List<Object?> get props => [
        totalSubmissions,
        approvalRate,
        avgProcessingTimeHours,
        autoApprovalRate,
        confidenceDistribution,
        aiNarrative,
      ];
}
