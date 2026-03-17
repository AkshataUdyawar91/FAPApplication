import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Floating Action Button for Chat - Available to all personas
class ChatFAB extends StatelessWidget {
  final String token;
  final String userName;

  const ChatFAB({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'token': token,
            'userName': userName,
          },
        );
      },
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text('AI Assistant'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
    );
  }
}
