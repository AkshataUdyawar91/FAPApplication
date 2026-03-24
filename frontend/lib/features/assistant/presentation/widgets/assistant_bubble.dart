import 'package:flutter/material.dart';

/// Bot message bubble — left-aligned with avatar.
class AssistantBubble extends StatelessWidget {
  final String message;
  final Widget? child;
  final bool isActive; // when false, bubble is greyed out and non-interactive
  final bool greyChild; // when false, child is NOT greyed even if isActive=false

  const AssistantBubble({
    super.key,
    required this.message,
    this.child,
    this.isActive = true,
    this.greyChild = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isActive ? const Color(0xFF003087) : Colors.grey.shade400,
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
                    color: isActive ? Colors.grey.shade100 : Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 15, color: isActive ? Colors.black87 : Colors.grey.shade500),
                  ),
                ),
                if (child != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: (isActive || !greyChild)
                        ? child!
                        : IgnorePointer(
                            child: Opacity(opacity: 0.4, child: child!),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
