import 'action_button_model.dart';
import 'card_data_model.dart';

/// DTO for the bot's response from the conversation endpoint.
class ConversationResponseModel {
  final String submissionId;
  final int currentStep;
  final String botMessage;
  final List<ActionButtonModel> buttons;
  final CardDataModel? card;
  final bool requiresFileUpload;
  final String? fileUploadType;
  final int progressPercent;
  final String? error;

  const ConversationResponseModel({
    required this.submissionId,
    required this.currentStep,
    required this.botMessage,
    this.buttons = const [],
    this.card,
    this.requiresFileUpload = false,
    this.fileUploadType,
    this.progressPercent = 0,
    this.error,
  });

  factory ConversationResponseModel.fromJson(Map<String, dynamic> json) {
    return ConversationResponseModel(
      submissionId: json['submissionId'] as String,
      currentStep: json['currentStep'] as int,
      botMessage: json['botMessage'] as String,
      buttons: (json['buttons'] as List<dynamic>?)
              ?.map((e) =>
                  ActionButtonModel.fromJson(e as Map<String, dynamic>),)
              .toList() ??
          [],
      card: json['card'] != null
          ? CardDataModel.fromJson(json['card'] as Map<String, dynamic>)
          : null,
      requiresFileUpload: json['requiresFileUpload'] as bool? ?? false,
      fileUploadType: json['fileUploadType'] as String?,
      progressPercent: json['progressPercent'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'submissionId': submissionId,
      'currentStep': currentStep,
      'botMessage': botMessage,
      'buttons': buttons.map((e) => e.toJson()).toList(),
      if (card != null) 'card': card!.toJson(),
      'requiresFileUpload': requiresFileUpload,
      if (fileUploadType != null) 'fileUploadType': fileUploadType,
      'progressPercent': progressPercent,
      if (error != null) 'error': error,
    };
  }
}
