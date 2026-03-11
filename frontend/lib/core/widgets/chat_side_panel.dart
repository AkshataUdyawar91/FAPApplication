import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../responsive/responsive.dart';

/// Shared chat side panel widget extracted from Agency dashboard.
/// Manages its own chat state internally.
class ChatSidePanel extends StatefulWidget {
  final String token;
  final String userName;
  final DeviceType deviceType;
  final VoidCallback onClose;

  const ChatSidePanel({
    super.key,
    required this.token,
    this.userName = 'User',
    required this.deviceType,
    required this.onClose,
  });

  @override
  State<ChatSidePanel> createState() => _ChatSidePanelState();
}

class _ChatSidePanelState extends State<ChatSidePanel> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
  final _chatController = TextEditingController();
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isSendingMessage = false;
  String? _conversationId;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = widget.deviceType == DeviceType.tablet ? 300.0 : 380.0;
    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: _buildChatContent(showClose: true),
    );
  }

  Widget _buildChatContent({bool showClose = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Ask me anything about your submissions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (showClose)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                ),
            ],
          ),
        ),
        Expanded(
          child: _chatMessages.isEmpty
              ? _buildChatEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    return _buildChatMessage(
                      msg['text'] as String,
                      msg['isUser'] as bool,
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isSendingMessage,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSendingMessage ? null : _sendMessage,
                icon: _isSendingMessage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about your submissions, status updates, or any questions',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestedQuestion('What is my latest submission status?'),
                _buildSuggestedQuestion('How many pending requests do I have?'),
                _buildSuggestedQuestion('Show me approved submissions'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestion(String question) {
    return InkWell(
      onTap: () {
        _chatController.text = question;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          question,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildChatMessage(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isUser
            ? Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              )
            : _buildRichText(text),
      ),
    );
  }

  /// Parses markdown-style links [text](url) and renders them as clickable spans.
  /// Supports both https:// links (open in browser) and doc:// links (download via API then open).
  Widget _buildRichText(String text) {
    // Match http(s), doc://, and nav:// protocol links
    final linkPattern = RegExp(r'\[([^\]]+)\]\(((https?|doc|nav)://[^\)]+)\)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in linkPattern.allMatches(text)) {
      // Add text before the link
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        ));
      }
      // Add the clickable link
      final linkText = match.group(1)!;
      final linkUrl = match.group(2)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _handleLinkTap(linkUrl),
          child: Text(
            linkText,
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF2563EB),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      ));
    }

    // If no links found, return simple text
    if (spans.isEmpty) {
      return Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Handles link taps — doc:// downloads via API, nav:// navigates in-app, https:// opens directly.
  Future<void> _handleLinkTap(String url) async {
    if (url.startsWith('doc://')) {
      final docId = url.replaceFirst('doc://', '');
      await _openDocumentById(docId);
    } else if (url.startsWith('nav://')) {
      // In-app navigation: nav://asm-review/{id} or nav://hq-review/{id}
      final path = url.replaceFirst('nav://', '');
      final parts = path.split('/');
      if (parts.length >= 2) {
        final route = parts[0]; // e.g. "asm-review" or "hq-review"
        final submissionId = parts[1];
        String routePath;
        if (route == 'asm-review') {
          routePath = '/asm/review-detail';
        } else if (route == 'hq-review') {
          routePath = '/hq/review-detail';
        } else if (route == 'agency-detail') {
          routePath = '/agency/submission-detail';
        } else {
          routePath = '/agency/submission-detail';
        }
        if (mounted) {
          Navigator.pushNamed(context, routePath, arguments: {
            'submissionId': submissionId,
            'token': widget.token,
            'userName': widget.userName,
          });
        }
      }
    } else {
      try {
        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = url;
        anchor.target = '_blank';
        anchor.click();
      } catch (_) {}
    }
  }

  /// Downloads a document by ID via the API and opens it in a new browser tab.
  /// Uses the same logic as _downloadDocument in agency_submission_detail_page.
  Future<void> _openDocumentById(String docId) async {
    try {
      final response = await _dio.get(
        '/documents/$docId/download',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final base64Content = response.data['base64Content']?.toString() ?? '';
        final contentType = response.data['contentType']?.toString() ?? 'application/octet-stream';

        if (base64Content.isEmpty) {
          _showSnackBar('Document content is empty.');
          return;
        }

        // Decode base64 and create a Blob URL — same approach as detail page
        final bytes = base64.decode(base64Content);
        final blob = web.Blob(
          [Uint8List.fromList(bytes).toJS].toJS,
          web.BlobPropertyBag(type: contentType),
        );
        final url = web.URL.createObjectURL(blob);

        // Open in new tab
        web.window.open(url, '_blank');
      } else {
        _showSnackBar('Failed to download document.');
      }
    } catch (e) {
      _showSnackBar('Error opening document: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    final userMessage = _chatController.text.trim();
    _chatController.clear();
    setState(() {
      _chatMessages.add({'text': userMessage, 'isUser': true});
      _isSendingMessage = true;
    });
    try {
      final requestData = <String, dynamic>{'message': userMessage};
      if (_conversationId != null) {
        requestData['conversationId'] = _conversationId;
      }
      final response = await _dio.post(
        '/chat/message',
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );
      if (response.statusCode == 200 && mounted) {
        // Store conversationId for subsequent messages
        final convId = response.data['conversationId']?.toString();
        if (convId != null && convId.isNotEmpty) {
          _conversationId = convId;
        }
        setState(() => _chatMessages.add({
              'text': response.data['message'] ?? 'I received your message.',
              'isUser': false,
            }));
      }
    } catch (e) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _chatMessages.add({
              'text': _getMockResponse(userMessage),
              'isUser': false,
            }));
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  String _getMockResponse(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('status') || lower.contains('latest')) {
      return 'Let me check your submission status for you.';
    } else if (lower.contains('pending')) {
      return 'Let me look up your pending requests.';
    } else if (lower.contains('approved')) {
      return 'Let me check your approved submissions.';
    } else if (lower.contains('help')) {
      return 'I can help you with:\n• Check submission status\n• View pending requests\n• Get approval statistics\n• Answer questions about your submissions';
    }
    return 'I understand your question. The AI chat service will be available once Azure OpenAI is configured.';
  }
}
