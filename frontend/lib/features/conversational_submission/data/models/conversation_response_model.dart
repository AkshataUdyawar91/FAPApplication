import 'action_button_model.dart';
import 'card_data_model.dart';
import 'validation_result_model.dart';

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
    // Build card from explicit 'card' field or synthesize from validationRules
    CardDataModel? card;
    if (json['card'] != null) {
      card = CardDataModel.fromJson(json['card'] as Map<String, dynamic>);
    } else if (json['validationRules'] != null &&
        (json['validationRules'] as List<dynamic>).isNotEmpty) {
      // Synthesize a ValidationResultCardModel from flat validationRules array
      final rules = (json['validationRules'] as List<dynamic>)
          .map((e) => ValidationResultModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final type = json['type'] as String? ?? '';
      final docType = type.replaceAll('_validation', '').split('_').map(
        (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
      ).join(' ');
      card = ValidationResultCardModel(
        documentType: docType,
        allPassed: (json['failedCount'] as int?) == 0,
        rules: rules,
      );
    }

    return ConversationResponseModel(
      submissionId: json['submissionId'] as String,
      currentStep: json['currentStep'] as int,
      botMessage: json['botMessage'] as String,
      buttons: (json['buttons'] as List<dynamic>?)
              ?.map((e) =>
                  ActionButtonModel.fromJson(e as Map<String, dynamic>),)
              .toList() ??
          [],
      card: card,
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
