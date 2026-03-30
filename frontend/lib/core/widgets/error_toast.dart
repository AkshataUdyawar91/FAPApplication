import 'package:flutter/material.dart';
import '../error/error_presentation.dart';
import '../theme/app_colors.dart';

/// A non-blocking overlay toast for error display.
/// Renders icon, message, dismiss button, and optional retry button.
class ErrorToast extends StatelessWidget {
  final ErrorPresentation presentation;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const ErrorToast({
    super.key,
    required this.presentation,
    this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: presentation.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: presentation.accentColor,
                  width: 4,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  presentation.icon,
                  color: presentation.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    presentation.message,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (presentation.isRetryable && onRetry != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Capture retry callback before dismiss removes the overlay
                      final retryCallback = onRetry!;
                      onDismiss();
                      // Execute retry after the frame completes to avoid
                      // conflicts with overlay removal
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        retryCallback();
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: presentation.accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 36),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
