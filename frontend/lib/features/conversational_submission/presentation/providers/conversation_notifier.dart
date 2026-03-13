import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/repositories/conversation_repository.dart';

/// State for the conversational submission chat.
class ConversationChatState extends Equatable {
  final List<ConversationMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? submissionId;
  final int currentStep;
  final int progressPercent;

  const ConversationChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.submissionId,
    this.currentStep = 0,
    this.progressPercent = 0,
  });

  ConversationChatState copyWith({
    List<ConversationMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? submissionId,
    int? currentStep,
    int? progressPercent,
  }) {
    return ConversationChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      submissionId: submissionId ?? this.submissionId,
      currentStep: currentStep ?? this.currentStep,
      progressPercent: progressPercent ?? this.progressPercent,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isLoading,
        isSending,
        error,
        submissionId,
        currentStep,
        progressPercent,
      ];
}

/// Manages the chat message list, sends requests via repository,
/// handles responses, and tracks the current conversation step.
class ConversationNotifier extends StateNotifier<ConversationChatState> {
  final ConversationRepository repository;

  ConversationNotifier(this.repository)
      : super(const ConversationChatState());

  /// Starts a new conversation by sending the "greet" action.
  Future<void> startConversation() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.sendMessage(
      action: 'greet',
      submissionId: state.submissionId,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (response) {
        final botMessage = ConversationMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response.botMessage,
          sender: MessageSender.bot,
          timestamp: DateTime.now(),
          buttons: response.buttons,
          card: response.card,
          requiresFileUpload: response.requiresFileUpload,
          fileUploadType: response.fileUploadType,
          error: response.error,
        );
        state = state.copyWith(
          isLoading: false,
          messages: [...state.messages, botMessage],
          submissionId: response.submissionId,
          currentStep: response.currentStep,
          progressPercent: response.progressPercent,
        );
      },
    );
  }

  /// Resumes an existing draft submission.
  Future<void> resumeSubmission(String submissionId) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      submissionId: submissionId,
    );

    final result = await repository.resumeSubmission(submissionId);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (response) {
        final botMessage = ConversationMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response.botMessage,
          sender: MessageSender.bot,
          timestamp: DateTime.now(),
          buttons: response.buttons,
          card: response.card,
          requiresFileUpload: response.requiresFileUpload,
          fileUploadType: response.fileUploadType,
          error: response.error,
        );
        state = state.copyWith(
          isLoading: false,
          messages: [...state.messages, botMessage],
          submissionId: response.submissionId,
          currentStep: response.currentStep,
          progressPercent: response.progressPercent,
        );
      },
    );
  }

  /// Sends a free-text message from the user.
  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message immediately
    final userMessage = ConversationMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      error: null,
    );

    final result = await repository.sendMessage(
      submissionId: state.submissionId,
      action: 'message',
      message: text,
    );

    _handleResponse(result);
  }

  /// Sends an action button tap (e.g. "select_po", "confirm", "skip").
  Future<void> sendAction(String action, String? payloadJson) async {
    // Add user confirmation message
    final userMessage = ConversationMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      content: action.replaceAll('_', ' ').toUpperCase(),
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      error: null,
    );

    final result = await repository.sendMessage(
      submissionId: state.submissionId,
      action: action,
      payloadJson: payloadJson,
    );

    _handleResponse(result);
  }

  /// Handles a SignalR push event (extraction complete, validation complete).
  void handlePushEvent(String eventType, Map<String, dynamic> payload) {
    final botMessage = ConversationMessage(
      id: 'push-${DateTime.now().millisecondsSinceEpoch}',
      content: _pushEventMessage(eventType, payload),
      sender: MessageSender.bot,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, botMessage],
    );
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Resets the conversation to initial state.
  void reset() {
    state = const ConversationChatState();
  }

  void _handleResponse(
    dynamic result,
  ) {
    result.fold(
      (failure) => state = state.copyWith(
        isSending: false,
        error: failure.message,
      ),
      (ConversationResponseData response) {
        final botMessage = ConversationMessage(
          id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
          content: response.botMessage,
          sender: MessageSender.bot,
          timestamp: DateTime.now(),
          buttons: response.buttons,
          card: response.card,
          requiresFileUpload: response.requiresFileUpload,
          fileUploadType: response.fileUploadType,
          error: response.error,
        );
        state = state.copyWith(
          isSending: false,
          messages: [...state.messages, botMessage],
          submissionId: response.submissionId,
          currentStep: response.currentStep,
          progressPercent: response.progressPercent,
        );
      },
    );
  }

  String _pushEventMessage(String eventType, Map<String, dynamic> payload) {
    switch (eventType) {
      case 'ExtractionComplete':
        final docType = payload['documentType'] ?? 'Document';
        return '$docType extraction complete. Running validation...';
      case 'ValidationComplete':
        return 'Validation results are ready.';
      case 'SubmissionStatusChanged':
        final newStatus = payload['newStatus'] ?? 'updated';
        return 'Submission status changed to $newStatus.';
      default:
        return 'Update received.';
    }
  }
}
