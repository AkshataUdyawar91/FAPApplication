import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../providers/conversation_providers.dart';
import '../providers/conversation_notifier.dart';
import '../providers/signalr_notifier.dart';
import '../providers/file_upload_notifier.dart';
import '../widgets/chat_window.dart';
import '../widgets/step_progress_bar.dart';
import '../widgets/file_upload_zone.dart';

/// A side-panel version of the conversational submission chatbot.
/// Embeds within the agency dashboard instead of opening a separate page.
class ConversationalChatPanel extends ConsumerStatefulWidget {
  final String token;
  final VoidCallback onClose;

  const ConversationalChatPanel({
    super.key,
    required this.token,
    required this.onClose,
  });

  @override
  ConsumerState<ConversationalChatPanel> createState() =>
      _ConversationalChatPanelState();
}

class _ConversationalChatPanelState
    extends ConsumerState<ConversationalChatPanel> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid competing with dashboard load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), _initConversation);
    });
  }

  Future<void> _initConversation() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    // Ensure auth token is set
    final currentToken = ref.read(authTokenProvider);
    if (currentToken == null || currentToken.isEmpty) {
      ref.read(authTokenProvider.notifier).state = widget.token;
    }

    // Reset conversation state for a fresh start
    ref.read(conversationNotifierProvider.notifier).reset();

    // Start the conversation — SignalR connects lazily when submissionId arrives
    await ref.read(conversationNotifierProvider.notifier).startConversation();
  }

  void _handleSendMessage(String text) {
    ref.read(conversationNotifierProvider.notifier).sendTextMessage(text);
  }

  void _handleActionTap(String action, String? payloadJson) {
    ref.read(conversationNotifierProvider.notifier).sendAction(action, payloadJson);
  }

  Future<void> _handleFileUpload(PickedFileData file) async {
    final chatState = ref.read(conversationNotifierProvider);
    final submissionId = chatState.submissionId;
    if (submissionId == null) return;

    final fileUploadType = _fileUploadTypeForStep(chatState.currentStep);

    await ref.read(fileUploadNotifierProvider.notifier).uploadFile(
          fileBytes: file.bytes,
          fileName: file.fileName,
          submissionId: submissionId,
          documentType: fileUploadType,
        );
  }

  String _fileUploadTypeForStep(int step) {
    switch (step) {
      case 3: return 'Invoice';
      case 4: return 'ActivitySummary';
      case 5: return 'CostSummary';
      case 6: return 'Photo';
      case 7: return 'EnquiryDump';
      case 8: return 'AdditionalDocument';
      default: return 'Document';
    }
  }

  UploadMode _uploadModeForStep(int step) {
    if (step == 6) return UploadMode.camera;
    return UploadMode.document;
  }

  bool _shouldShowUploadZone(ConversationChatState state) {
    final lastMessage = state.messages.isNotEmpty ? state.messages.last : null;
    if (lastMessage == null) return false;
    return lastMessage.requiresFileUpload;
  }

  String _uploadLabel(int step) {
    switch (step) {
      case 3: return 'Upload Invoice';
      case 4: return 'Upload Activity Summary';
      case 5: return 'Upload Cost Summary';
      case 6: return 'Take Photo';
      case 7: return 'Upload Enquiry Dump';
      case 8: return 'Upload Additional Document';
      default: return 'Upload File';
    }
  }

  String _uploadHint(int step) {
    switch (step) {
      case 3: return 'PDF or image of the invoice';
      case 4: return 'PDF or image of the activity summary';
      case 5: return 'PDF or image of the cost summary';
      case 6: return 'Min 3, max 10 photos per team';
      case 7: return 'Excel (.xlsx, .csv) or PDF';
      case 8: return 'Any supporting documents';
      default: return '';
    }
  }

  FileUploadStatus _mapUploadStatus(UploadPhase phase) {
    switch (phase) {
      case UploadPhase.idle: return FileUploadStatus.idle;
      case UploadPhase.compressing: return FileUploadStatus.compressing;
      case UploadPhase.uploading: return FileUploadStatus.uploading;
      case UploadPhase.polling: return FileUploadStatus.uploading;
      case UploadPhase.complete: return FileUploadStatus.success;
      case UploadPhase.error: return FileUploadStatus.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(conversationNotifierProvider);
    final uploadState = ref.watch(fileUploadNotifierProvider);
    final signalRState = ref.watch(signalRNotifierProvider);

    // Join SignalR group when submissionId becomes available
    _joinSignalRGroupIfNeeded(chatState, signalRState);

    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF003087),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_comment, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Submission',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Guided claim submission',
                            style: TextStyle(fontSize: 12, color: Color(0xFFBFDBFE)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: widget.onClose,
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: chatState.progressPercent / 100.0,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${chatState.currentStep}/10',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFBFDBFE)),
                    ),
                    Text(
                      '${chatState.progressPercent}%',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFBFDBFE)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Error banner
          if (chatState.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () => ref.read(conversationNotifierProvider.notifier).clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Chat window
          Expanded(
            child: ChatWindow(
              messages: chatState.messages,
              isSending: chatState.isSending,
              isLoading: chatState.isLoading,
              onSendMessage: _handleSendMessage,
              onActionTap: _handleActionTap,
            ),
          ),
          // File upload zone
          if (_shouldShowUploadZone(chatState))
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FileUploadZone(
                mode: _uploadModeForStep(chatState.currentStep),
                label: _uploadLabel(chatState.currentStep),
                hint: _uploadHint(chatState.currentStep),
                status: _mapUploadStatus(uploadState.phase),
                uploadProgress: uploadState.uploadProgress,
                errorMessage: uploadState.errorMessage,
                onFileReady: _handleFileUpload,
                onRetry: uploadState.phase == UploadPhase.error
                    ? () => ref.read(fileUploadNotifierProvider.notifier).reset()
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  void _joinSignalRGroupIfNeeded(
    ConversationChatState chatState,
    SignalRState signalRState,
  ) {
    final submissionId = chatState.submissionId;
    if (submissionId == null) return;

    // Connect SignalR lazily — only once we have a submissionId
    if (signalRState.status == SignalRConnectionStatus.disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final token = ref.read(authTokenProvider);
        if (token != null && token.isNotEmpty) {
          await ref.read(signalRNotifierProvider.notifier).connect(token);
        }
      });
      return;
    }

    if (signalRState.status == SignalRConnectionStatus.connected &&
        signalRState.currentSubmissionId != submissionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(signalRNotifierProvider.notifier).joinSubmission(submissionId);
      });
    }
  }
}
