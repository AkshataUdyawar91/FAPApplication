import '../../domain/entities/kpi_dashboard.dart';

class KPIDashboardModel extends KPIDashboard {
  const KPIDashboardModel({
    required super.totalSubmissions,
    required super.approvalRate,
    required super.avgProcessingTimeHours,
    required super.autoApprovalRate,
    required super.confidenceDistribution,
    required super.aiNarrative,
  });

  factory KPIDashboardModel.fromJson(Map<String, dynamic> json) {
    return KPIDashboardModel(
      totalSubmissions: json['totalSubmissions'] as int,
      approvalRate: (json['approvalRate'] as num).toDouble(),
      avgProcessingTimeHours:
          (json['avgProcessingTimeHours'] as num).toDouble(),
      autoApprovalRate: (json['autoApprovalRate'] as num).toDouble(),
      confidenceDistribution: Map<String, int>.from(
        json['confidenceDistribution'] as Map<String, dynamic>,
      ),
      aiNarrative: json['aiNarrative'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSubmissions': totalSubmissions,
      'approvalRate': approvalRate,
      'avgProcessingTimeHours': avgProcessingTimeHours,
      'autoApprovalRate': autoApprovalRate,
      'confidenceDistribution': confidenceDistribution,
      'aiNarrative': aiNarrative,
    };
  }
}
