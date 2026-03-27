import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable empty state widget displayed when a list or page has no data.
///
/// Shows a centered layout with an icon, title, and message.
/// Optionally displays an action button when both [actionLabel]
/// and [onAction] are provided.
class EmptyStateWidget extends StatelessWidget {
  /// The illustrative icon displayed at the top.
  final IconData icon;

  /// The title text displayed below the icon.
  final String title;

  /// The descriptive message displayed below the title.
  final String message;

  /// Optional label for the action button.
  /// The button is only shown when both [actionLabel] and [onAction] are provided.
  final String? actionLabel;

  /// Optional callback invoked when the action button is tapped.
  /// The button is only shown when both [actionLabel] and [onAction] are provided.
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
