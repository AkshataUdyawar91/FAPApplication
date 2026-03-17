import '../../domain/entities/conversation_message.dart';

/// Data model for ActionButton with JSON serialization.
class ActionButtonModel extends ActionButton {
  const ActionButtonModel({
    required super.label,
    required super.action,
    super.payloadJson,
  });

  factory ActionButtonModel.fromJson(Map<String, dynamic> json) {
    return ActionButtonModel(
      label: json['label'] as String,
      action: json['action'] as String,
      payloadJson: json['payloadJson'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'action': action,
      if (payloadJson != null) 'payloadJson': payloadJson,
    };
  }
}
