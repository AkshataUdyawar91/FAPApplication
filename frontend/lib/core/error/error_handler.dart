import 'package:flutter/material.dart';
import 'error_presentation.dart';
import 'failures.dart';
import 'error_toast_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/error_dialog.dart';

/// Centralized mapping from [Failure] → [ErrorPresentation].
/// Provides [show()] to dispatch the correct UI (toast vs dialog).
abstract class ErrorHandler {
  /// Maps a Failure to its UI presentation.
  static ErrorPresentation mapFailure(Failure failure) {
    // Default messages per subtype
    const networkDefault = 'Network error occurred';
    const serverDefault = 'Server error occurred';
    const authDefault = 'Authentication failed';
    const validationDefault = 'Validation failed';
    const notFoundDefault = 'Resource not found';
    const cacheDefault = 'Cache error occurred';

    if (failure is NetworkFailure) {
      final message = (failure.message != networkDefault && failure.message.isNotEmpty)
          ? failure.message
          : 'No internet connection. Check your network and try again.';
      return ErrorPresentation(
        icon: Icons.wifi_off,
        message: message,
        accentColor: AppColors.pendingText,
        backgroundColor: AppColors.pendingBackground,
        isRetryable: true,
      );
    }

    if (failure is ServerFailure) {
      final message = (failure.message != serverDefault && failure.message.isNotEmpty)
          ? failure.message
          : 'Something went wrong on our end. Please try again later.';
      return ErrorPresentation(
        icon: Icons.cloud_off,
        message: message,
        accentColor: AppColors.rejectedText,
        backgroundColor: AppColors.rejectedBackground,
        isRetryable: true,
      );
    }

    if (failure is AuthFailure) {
      final message = (failure.message != authDefault && failure.message.isNotEmpty)
          ? failure.message
          : 'Your session has expired. Please sign in again.';
      return ErrorPresentation(
        icon: Icons.lock_outline,
        message: message,
        accentColor: AppColors.reviewText,
        backgroundColor: AppColors.reviewBackground,
      );
    }

    if (failure is ValidationFailure) {
      final message = (failure.message != validationDefault && failure.message.isNotEmpty)
          ? failure.message
          : 'Please check your input and try again.';
      return ErrorPresentation(
        icon: Icons.warning_amber_rounded,
        message: message,
        accentColor: AppColors.pendingText,
        backgroundColor: AppColors.pendingBackground,
      );
    }

    if (failure is NotFoundFailure) {
      final message = (failure.message != notFoundDefault && failure.message.isNotEmpty)
          ? failure.message
          : 'The requested resource could not be found.';
      return ErrorPresentation(
        icon: Icons.search_off,
        message: message,
        accentColor: AppColors.textSecondary,
        backgroundColor: AppColors.inputBackground,
      );
    }

    if (failure is CacheFailure) {
      final message = (failure.message != cacheDefault && failure.message.isNotEmpty)
          ? failure.message
          : 'Local data could not be loaded. Please try again.';
      return ErrorPresentation(
        icon: Icons.storage_rounded,
        message: message,
        accentColor: AppColors.pendingText,
        backgroundColor: AppColors.pendingBackground,
        isRetryable: true,
      );
    }

    // Fallback for unknown failure types
    return ErrorPresentation(
      icon: Icons.error_outline,
      message: failure.message.isNotEmpty ? failure.message : 'An unexpected error occurred.',
      accentColor: AppColors.rejectedText,
      backgroundColor: AppColors.rejectedBackground,
    );
  }

  /// Shows the appropriate error UI (toast or dialog).
  /// For AuthFailure: shows ErrorDialog.
  /// For all others: shows ErrorToast.
  static void show(
    BuildContext context, {
    required Failure failure,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    if (failure is AuthFailure) {
      ErrorDialog.showAuthError(context);
      return;
    }
    final presentation = mapFailure(failure);
    ErrorToastManager().show(context, presentation, onRetry: onRetry);
  }

  /// Creates the appropriate Failure from an error message string.
  /// Detects auth-related messages and returns AuthFailure for them.
  static Failure failureFromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('session') ||
        lower.contains('sign in') ||
        lower.contains('unauthorized') ||
        lower.contains('expired') ||
        lower.contains('forbidden')) {
      return AuthFailure(message);
    }
    if (lower.contains('no internet') ||
        lower.contains('network') ||
        lower.contains('connection')) {
      return NetworkFailure(message);
    }
    return ServerFailure(message);
  }
}
