import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_message_usecase.dart';

class ChatState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<ChatMessage> messages;
  final bool isSending;

  const ChatState({
    this.isLoading = false,
    this.error,
    this.messages = const [],
    this.isSending = false,
  });

  ChatState copyWith({
    bool? isLoading,
    String? error,
    List<ChatMessage>? messages,
    bool? isSending,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, messages, isSending];
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository repository;
  final SendMessageUseCase sendMessageUseCase;

  ChatNotifier(
    this.repository,
    this.sendMessageUseCase,
  ) : super(const ChatState());

  Future<void> loadConversationHistory() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getConversationHistory();

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (messages) => state = state.copyWith(
        isLoading: false,
        messages: messages,
      ),
    );
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Add user message immediately
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      error: null,
    );

    final result = await sendMessageUseCase(content);

    result.fold(
      (failure) => state = state.copyWith(
        isSending: false,
        error: failure.message,
      ),
      (response) => state = state.copyWith(
        messages: [...state.messages, response],
        isSending: false,
      ),
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearConversation() {
    state = const ChatState();
  }
}
