import '../../domain/entities/campaign_breakdown.dart';

class CampaignBreakdownModel extends CampaignBreakdown {
  const CampaignBreakdownModel({
    required super.campaignName,
    required super.submissionCount,
    required super.approvalRate,
    required super.avgConfidenceScore,
  });

  factory CampaignBreakdownModel.fromJson(Map<String, dynamic> json) {
    return CampaignBreakdownModel(
      campaignName: json['campaignName'] as String,
      submissionCount: json['submissionCount'] as int,
      approvalRate: (json['approvalRate'] as num).toDouble(),
      avgConfidenceScore: (json['avgConfidenceScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaignName': campaignName,
      'submissionCount': submissionCount,
      'approvalRate': approvalRate,
      'avgConfidenceScore': avgConfidenceScore,
    };
  }
}
