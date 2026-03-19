import 'package:flutter/material.dart';
import '_admin_placeholder.dart';

class DealerMasterPage extends StatelessWidget {
  final String token;
  const DealerMasterPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) =>
      const AdminPlaceholder(title: 'Dealer Master', icon: Icons.store);
}
