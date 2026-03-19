import 'package:flutter/material.dart';
import '_admin_placeholder.dart';

class StateCityMasterPage extends StatelessWidget {
  final String token;
  const StateCityMasterPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) =>
      const AdminPlaceholder(title: 'State City Master', icon: Icons.map_outlined);
}
