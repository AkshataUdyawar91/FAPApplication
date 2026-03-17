import 'package:flutter/material.dart';
import '../../domain/entities/conversation_message.dart';
import 'bot_message_bubble.dart';
import 'user_message_bubble.dart';
import 'action_buttons_row.dart';

/// The main chat window widget for the conversational submission flow.
///
/// Displays a scrollable list of messages with auto-scroll to bottom,
/// and an input area at the bottom for free-text entry.
class ChatWindow extends StatefulWidget {
  final List<ConversationMessage> messages;
  final bool isSending;
  final bool isLoading;
  final ValueChanged<String> onSendMessage;
  final void Function(String action, String? payloadJson) onActionTap;

  const ChatWindow({
    super.key,
    required this.messages,
    required this.onSendMessage,
    required this.onActionTap,
    this.isSending = false,
    this.isLoading = false,
  });

  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  @override
  void didUpdateWidget(covariant ChatWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: widget.isLoading && widget.messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : widget.messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(),
        ),
        _buildInputArea(context),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a new submission',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your guided claim submission starts here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isLastBotMessage = message.sender == MessageSender.bot &&
            (index == widget.messages.length - 1 ||
                widget.messages[index + 1].sender == MessageSender.user);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message.sender == MessageSender.bot)
              BotMessageBubble(
                key: ValueKey(message.id),
                message: message,
                onActionTap: widget.onActionTap,
              )
            else
              UserMessageBubble(
                key: ValueKey(message.id),
                message: message,
              ),
            if (isLastBotMessage && message.buttons.isNotEmpty)
              ActionButtonsRow(
                buttons: message.buttons,
                onActionTap: widget.onActionTap,
              ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                enabled: !widget.isSending,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF003087),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: widget.isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: widget.isSending ? null : _handleSend,
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
