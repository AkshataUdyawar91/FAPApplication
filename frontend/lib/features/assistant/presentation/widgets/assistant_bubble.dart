import 'package:flutter/material.dart';

/// Bot message bubble — left-aligned with avatar.
class AssistantBubble extends StatelessWidget {
  final String message;
  final Widget? child;

  const AssistantBubble({
    super.key,
    required this.message,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF003087),
            child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                if (child != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: child!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
