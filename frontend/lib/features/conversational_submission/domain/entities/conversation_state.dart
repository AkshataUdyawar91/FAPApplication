import 'package:equatable/equatable.dart';

/// Conversation step enum matching the backend ConversationStep.
enum ConversationStep {
  greeting,
  poSelection,
  stateSelection,
  invoiceUpload,
  activitySummaryUpload,
  costSummaryUpload,
  teamDetailsLoop,
  enquiryDumpUpload,
  additionalDocsUpload,
  finalReview,
  submitted,
}

/// Tracks the current state of a conversational submission session.
class ConversationState extends Equatable {
  final String submissionId;
  final ConversationStep currentStep;
  final int progressPercent;
  final ConversationStep? lastCompletedStep;

  const ConversationState({
    required this.submissionId,
    required this.currentStep,
    required this.progressPercent,
    this.lastCompletedStep,
  });

  @override
  List<Object?> get props => [
        submissionId,
        currentStep,
        progressPercent,
        lastCompletedStep,
      ];
}
