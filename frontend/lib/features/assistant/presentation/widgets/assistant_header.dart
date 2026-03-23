import 'package:flutter/material.dart';

/// Copilot-style header for the assistant.
class AssistantHeader extends StatelessWidget implements PreferredSizeWidget {
  const AssistantHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF003087),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: const Padding(
        padding: EdgeInsets.all(12),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          radius: 18,
          child: Icon(Icons.smart_toy, color: Color(0xFF003087), size: 20),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FieldIQ Assistant',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            'Online',
            style: TextStyle(fontSize: 12, color: Color(0xFF90CAF9)),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'New conversation',
          onPressed: () {},
        ),
      ],
    );
  }
}
