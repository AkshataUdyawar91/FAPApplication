import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/assistant/presentation/providers/assistant_providers.dart';
import '../network/dio_client.dart';

/// Modal dialog for critical errors (AuthFailure).
/// Non-dismissible by tapping outside. Deduplicates — won't show
/// a second dialog if one is already visible.
class ErrorDialog {
  static bool _isShowing = false;

  /// Shows a modal auth error dialog.
  /// Clears auth state and navigates to `/login` when the user taps "Sign In".
  static Future<void> showAuthError(BuildContext context) async {
    if (_isShowing) return;
    if (!context.mounted) return;

    _isShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(
          Icons.lock_outline,
          size: 48,
          color: AppColors.reviewText,
        ),
        title: const Text(
          'Session Expired',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Your session has expired. Please sign in again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Close dialog first
                Navigator.of(dialogContext).pop();

                // Clear auth state so router redirect allows /login
                final container = ProviderScope.containerOf(context);
                container.read(assistantNotifierProvider.notifier).reset();
                container.read(authTokenProvider.notifier).state = null;
                container.read(authNotifierProvider.notifier).logout();

                // Navigate to login
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    _isShowing = false;
  }
}
