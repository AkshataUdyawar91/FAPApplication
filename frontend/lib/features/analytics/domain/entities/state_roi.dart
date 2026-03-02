import 'package:equatable/equatable.dart';

class StateROI extends Equatable {
  final String state;
  final int submissionCount;
  final double approvalRate;
  final double avgProcessingTimeHours;
  final double roi;

  const StateROI({
    required this.state,
    required this.submissionCount,
    required this.approvalRate,
    required this.avgProcessingTimeHours,
    required this.roi,
  });

  @override
  List<Object?> get props => [
        state,
        submissionCount,
        approvalRate,
        avgProcessingTimeHours,
        roi,
      ];
}
