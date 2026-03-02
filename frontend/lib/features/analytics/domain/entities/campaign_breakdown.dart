import 'package:equatable/equatable.dart';

class CampaignBreakdown extends Equatable {
  final String campaignName;
  final int submissionCount;
  final double approvalRate;
  final double avgConfidenceScore;

  const CampaignBreakdown({
    required this.campaignName,
    required this.submissionCount,
    required this.approvalRate,
    required this.avgConfidenceScore,
  });

  @override
  List<Object?> get props => [
        campaignName,
        submissionCount,
        approvalRate,
        avgConfidenceScore,
      ];
}
