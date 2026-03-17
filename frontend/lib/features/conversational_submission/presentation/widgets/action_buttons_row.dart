import 'package:flutter/material.dart';
import '../../domain/entities/conversation_message.dart';

/// A row of action buttons rendered below bot messages.
///
/// Uses a [Wrap] widget so buttons flow to the next line on narrow screens.
/// Tapping a button triggers [onActionTap] with the button's action and
/// optional payloadJson, which the parent uses to send a [ConversationRequest].
class ActionButtonsRow extends StatelessWidget {
  final List<ActionButton> buttons;
  final void Function(String action, String? payloadJson) onActionTap;

  const ActionButtonsRow({
    super.key,
    required this.buttons,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: buttons.map((button) {
          return ElevatedButton(
            onPressed: () => onActionTap(button.action, button.payloadJson),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(fontSize: 14),
            ),
            child: Text(button.label),
          );
        }).toList(),
      ),
    );
  }
}
