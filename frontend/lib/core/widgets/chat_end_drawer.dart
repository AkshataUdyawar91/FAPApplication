import 'package:flutter/material.dart';
import '../responsive/responsive.dart';
import 'chat_side_panel.dart';

/// Shared chat end drawer for mobile viewports.
/// Wraps ChatSidePanel content in a Drawer widget.
class ChatEndDrawer extends StatelessWidget {
  final String token;

  const ChatEndDrawer({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: ChatSidePanel(
          token: token,
          deviceType: DeviceType.mobile,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
