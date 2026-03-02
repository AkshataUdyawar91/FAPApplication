import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
    super.citations,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.parse(json['timestamp'] as String),
      citations: (json['citations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp.toIso8601String(),
      'citations': citations,
    };
  }
}
