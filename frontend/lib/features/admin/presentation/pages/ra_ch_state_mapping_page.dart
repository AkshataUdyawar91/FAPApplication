import 'package:flutter/material.dart';
import '_admin_placeholder.dart';

class RaChStateMappingPage extends StatelessWidget {
  final String token;
  const RaChStateMappingPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) =>
      const AdminPlaceholder(title: 'RA/CH/State Mapping', icon: Icons.account_tree_outlined);
}
