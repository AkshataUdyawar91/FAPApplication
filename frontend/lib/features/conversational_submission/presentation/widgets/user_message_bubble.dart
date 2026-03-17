import 'package:flutter/material.dart';
import '../../domain/entities/conversation_message.dart';

/// User message bubble for text input and action confirmations.
///
/// Displays right-aligned with the ClaimsIQ brand color (#003087).
/// Supports both free-text messages and action confirmation labels.
class UserMessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const UserMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600
        ? screenWidth * 0.6
        : screenWidth * 0.85;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF003087),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
