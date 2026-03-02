import '../../domain/entities/state_roi.dart';

class StateROIModel extends StateROI {
  const StateROIModel({
    required super.state,
    required super.submissionCount,
    required super.approvalRate,
    required super.avgProcessingTimeHours,
    required super.roi,
  });

  factory StateROIModel.fromJson(Map<String, dynamic> json) {
    return StateROIModel(
      state: json['state'] as String,
      submissionCount: json['submissionCount'] as int,
      approvalRate: (json['approvalRate'] as num).toDouble(),
      avgProcessingTimeHours:
          (json['avgProcessingTimeHours'] as num).toDouble(),
      roi: (json['roi'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'submissionCount': submissionCount,
      'approvalRate': approvalRate,
      'avgProcessingTimeHours': avgProcessingTimeHours,
      'roi': roi,
    };
  }
}
