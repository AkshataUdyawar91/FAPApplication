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

/// Main chat page for the conversational submission flow.
///
/// Uses [ChatWindow] for the message list, [ConversationNotifier] for chat
/// state management, [SignalRNotifier] for real-time push events, and
/// [FileUploadNotifier] for document/photo uploads.
class ConversationalSubmissionPage extends ConsumerStatefulWidget {
  const ConversationalSubmissionPage({super.key});

  @override
  ConsumerState<ConversationalSubmissionPage> createState() =>
      _ConversationalSubmissionPageState();
}

class _ConversationalSubmissionPageState
    extends ConsumerState<ConversationalSubmissionPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize conversation and SignalR on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initConversation();
    });
  }

  Future<void> _initConversation() async {
    if (_initialized) return;
    _initialized = true;

    // Start the conversation
    await ref.read(conversationNotifierProvider.notifier).startConversation();

    // Connect SignalR with auth token
    final token = ref.read(authTokenProvider);
    if (token != null && token.isNotEmpty) {
      await ref
          .read(signalRNotifierProvider.notifier)
          .connect(token);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleSendMessage(String text) {
    ref.read(conversationNotifierProvider.notifier).sendTextMessage(text);
  }

  void _handleActionTap(String action, String? payloadJson) {
    ref.read(conversationNotifierProvider.notifier).sendAction(
          action,
          payloadJson,
        );
  }

  Future<void> _handleFileUpload(PickedFileData file) async {
    final chatState = ref.read(conversationNotifierProvider);
    final submissionId = chatState.submissionId;
    if (submissionId == null) return;

    // Determine document type from current step
    final fileUploadType = _fileUploadTypeForStep(chatState.currentStep);

    // Wire the upload-success callback before starting the upload so it's
    // set when the notifier fires it (immediately after documentId is returned).
    ref.read(fileUploadNotifierProvider.notifier).onUploadSuccess = (documentId) {
      if (!mounted) return;
      ref.read(conversationNotifierProvider.notifier).sendAction(
            'upload_confirmed',
            '{"documentId":"$documentId"}',
          );
      // Reset upload zone so it's ready for the next document
      ref.read(fileUploadNotifierProvider.notifier).reset();
    };

    await ref.read(fileUploadNotifierProvider.notifier).uploadFile(
          fileBytes: file.bytes,
          fileName: file.fileName,
          submissionId: submissionId,
          documentType: fileUploadType,
        );
  }

  String _fileUploadTypeForStep(int step) {
    switch (step) {
      case 3:
        return 'Invoice';
      case 4:
        return 'ActivitySummary';
      case 5:
        return 'CostSummary';
      case 6:
        return 'Photo';
      case 7:
        return 'EnquiryDump';
      case 8:
        return 'AdditionalDocument';
      default:
        return 'Document';
    }
  }

  UploadMode _uploadModeForStep(int step) {
    if (step == 6) return UploadMode.camera;
    return UploadMode.document;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(conversationNotifierProvider);
    final uploadState = ref.watch(fileUploadNotifierProvider);
    final signalRState = ref.watch(signalRNotifierProvider);

    // Join SignalR group when submissionId becomes available
    _joinSignalRGroupIfNeeded(chatState, signalRState);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Submission'),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        bottom: StepProgressBar(
          progressPercent: chatState.progressPercent,
          currentStep: chatState.currentStep,
        ),
      ),
      body: Column(
        children: [
          // Error banner
          if (chatState.error != null)
            MaterialBanner(
              content: Text(chatState.error!),
              backgroundColor: Colors.red.shade50,
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(conversationNotifierProvider.notifier)
                      .clearError(),
                  child: const Text('DISMISS'),
                ),
              ],
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
          // File upload zone (shown when current step requires upload)
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
                    ? () => ref
                        .read(fileUploadNotifierProvider.notifier)
                        .reset()
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
    if (submissionId != null &&
        signalRState.status == SignalRConnectionStatus.connected &&
        signalRState.currentSubmissionId != submissionId) {
      // Schedule after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(signalRNotifierProvider.notifier)
            .joinSubmission(submissionId);
      });
    }
  }

  bool _shouldShowUploadZone(ConversationChatState state) {
    // Show upload zone for steps that require file upload
    final lastMessage =
        state.messages.isNotEmpty ? state.messages.last : null;
    if (lastMessage == null) return false;
    return lastMessage.requiresFileUpload;
  }

  String _uploadLabel(int step) {
    switch (step) {
      case 3:
        return 'Upload Invoice';
      case 4:
        return 'Upload Activity Summary';
      case 5:
        return 'Upload Cost Summary';
      case 6:
        return 'Take Photo';
      case 7:
        return 'Upload Enquiry Dump';
      case 8:
        return 'Upload Additional Document';
      default:
        return 'Upload File';
    }
  }

  String _uploadHint(int step) {
    switch (step) {
      case 3:
        return 'PDF or image of the invoice';
      case 4:
        return 'PDF or image of the activity summary';
      case 5:
        return 'PDF or image of the cost summary';
      case 6:
        return 'Min 3, max 10 photos per team';
      case 7:
        return 'Excel (.xlsx, .csv) or PDF';
      case 8:
        return 'Any supporting documents';
      default:
        return '';
    }
  }

  FileUploadStatus _mapUploadStatus(UploadPhase phase) {
    switch (phase) {
      case UploadPhase.idle:
        return FileUploadStatus.idle;
      case UploadPhase.compressing:
        return FileUploadStatus.compressing;
      case UploadPhase.uploading:
        return FileUploadStatus.uploading;
      case UploadPhase.polling:
        return FileUploadStatus.uploading;
      case UploadPhase.complete:
        return FileUploadStatus.success;
      case UploadPhase.error:
        return FileUploadStatus.error;
    }
  }
}
