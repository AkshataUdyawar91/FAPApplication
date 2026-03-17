/// DTO for sending a conversation action to the backend.
class ConversationRequestModel {
  final String? submissionId;
  final String action;
  final String? message;
  final String? payloadJson;

  const ConversationRequestModel({
    this.submissionId,
    required this.action,
    this.message,
    this.payloadJson,
  });

  Map<String, dynamic> toJson() {
    return {
      if (submissionId != null) 'submissionId': submissionId,
      'action': action,
      if (message != null) 'message': message,
      if (payloadJson != null) 'payloadJson': payloadJson,
    };
  }
}
