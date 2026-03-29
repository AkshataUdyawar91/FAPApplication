import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Empty placeholder page for Validation Testing.
class ValidationTestingPage extends StatelessWidget {
  final String token;

  const ValidationTestingPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 64, color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Validation Testing',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
