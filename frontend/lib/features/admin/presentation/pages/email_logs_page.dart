import 'package:flutter/material.dart';
import '_admin_placeholder.dart';

class EmailLogsPage extends StatelessWidget {
  final String token;
  const EmailLogsPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) =>
      const AdminPlaceholder(title: 'Email Logs', icon: Icons.email_outlined);
}
