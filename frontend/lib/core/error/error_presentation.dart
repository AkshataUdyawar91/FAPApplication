import 'package:flutter/material.dart';

/// Maps a [Failure] to its UI representation (icon, message, color, retryable).
class ErrorPresentation {
  final IconData icon;
  final String message;
  final Color accentColor;
  final Color backgroundColor;
  final bool isRetryable;

  const ErrorPresentation({
    required this.icon,
    required this.message,
    required this.accentColor,
    required this.backgroundColor,
    this.isRetryable = false,
  });
}
