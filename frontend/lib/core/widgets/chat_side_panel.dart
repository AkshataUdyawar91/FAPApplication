import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../responsive/responsive.dart';

/// Shared chat side panel widget extracted from Agency dashboard.
/// Manages its own chat state internally.
class ChatSidePanel extends StatefulWidget {
  final String token;
  final DeviceType deviceType;
  final VoidCallback onClose;

  const ChatSidePanel({
    super.key,
    required this.token,
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
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isUser ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
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
      final response = await _dio.post(
        '/chat/message',
        data: {'message': userMessage},
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() => _chatMessages.add({
              'text': response.data['response'] ?? 'I received your message.',
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
