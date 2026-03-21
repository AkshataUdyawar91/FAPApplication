import 'package:flutter/material.dart';

/// Shared placeholder for admin screens not yet implemented.
class AdminPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;

  const AdminPlaceholder({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003087),
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(icon, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  '$title screen is under construction.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
