import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'error_presentation.dart';
import '../widgets/error_toast.dart';

/// Manages a queue of error toasts. Shows one at a time, auto-dismisses after 5 seconds.
class ErrorToastManager {
  static final ErrorToastManager _instance = ErrorToastManager._internal();
  factory ErrorToastManager() => _instance;
  ErrorToastManager._internal();

  OverlayEntry? _currentEntry;
  Timer? _autoDismissTimer;
  final Queue<_ToastRequest> _queue = Queue();
  bool _isShowing = false;

  /// Shows a toast. If one is already visible, queues it.
  void show(
    BuildContext context,
    ErrorPresentation presentation, {
    VoidCallback? onRetry,
  }) {
    _queue.add(_ToastRequest(
      context: context,
      presentation: presentation,
      onRetry: onRetry,
    ));
    if (!_isShowing) {
      _showNext();
    }
  }

  /// Dismisses the current toast and shows the next queued one.
  void dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {
      // OverlayEntry may already be removed
    }
    _currentEntry = null;
    _isShowing = false;
    if (_queue.isNotEmpty) {
      _showNext();
    }
  }

  void _showNext() {
    if (_queue.isEmpty) return;
    final request = _queue.removeFirst();

    // Verify context is still valid
    if (!request.context.mounted) {
      _isShowing = false;
      if (_queue.isNotEmpty) _showNext();
      return;
    }

    try {
      final overlay = Overlay.of(request.context);
      _isShowing = true;

      _currentEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ErrorToast(
            presentation: request.presentation,
            onRetry: request.onRetry,
            onDismiss: dismiss,
          ),
        ),
      );

      overlay.insert(_currentEntry!);

      // Auto-dismiss after 5 seconds
      _autoDismissTimer = Timer(const Duration(seconds: 5), dismiss);
    } catch (e) {
      // If overlay insertion fails, reset state and try next
      debugPrint('ErrorToastManager: Failed to show toast: $e');
      _isShowing = false;
      _currentEntry = null;
      if (_queue.isNotEmpty) _showNext();
    }
  }
}

class _ToastRequest {
  final BuildContext context;
  final ErrorPresentation presentation;
  final VoidCallback? onRetry;

  _ToastRequest({
    required this.context,
    required this.presentation,
    this.onRetry,
  });
}
