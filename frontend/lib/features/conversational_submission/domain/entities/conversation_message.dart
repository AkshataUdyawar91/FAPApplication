import 'package:equatable/equatable.dart';

enum MessageSender { bot, user }

/// Represents a single message in the conversational submission chat.
class ConversationMessage extends Equatable {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final List<ActionButton> buttons;
  final CardData? card;
  final bool requiresFileUpload;
  final String? fileUploadType;
  final String? error;

  const ConversationMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.buttons = const [],
    this.card,
    this.requiresFileUpload = false,
    this.fileUploadType,
    this.error,
  });

  @override
  List<Object?> get props => [
        id,
        content,
        sender,
        timestamp,
        buttons,
        card,
        requiresFileUpload,
        fileUploadType,
        error,
      ];
}

/// An action button displayed below a bot message.
class ActionButton extends Equatable {
  final String label;
  final String action;
  final String? payloadJson;

  const ActionButton({
    required this.label,
    required this.action,
    this.payloadJson,
  });

  @override
  List<Object?> get props => [label, action, payloadJson];
}

/// Base class for card data displayed in bot messages.
abstract class CardData extends Equatable {
  final String type;

  const CardData({required this.type});

  @override
  List<Object?> get props => [type];
}
