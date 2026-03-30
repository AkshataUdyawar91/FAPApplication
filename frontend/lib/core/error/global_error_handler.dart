import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Configures global error handlers for unhandled Flutter framework
/// and platform exceptions. Call [init] before [runApp] in main().
abstract class GlobalErrorHandler {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 5, errorMethodCount: 8),
  );

  /// Configures [FlutterError.onError] and
  /// [PlatformDispatcher.instance.onError] to catch all unhandled errors.
  static void init() {
    // Req 6.1 — catch unhandled framework errors
    FlutterError.onError = _handleFlutterError;

    // Req 6.2 — catch unhandled platform exceptions
    PlatformDispatcher.instance.onError = _handlePlatformError;

    // Req 6.5 — suppress red error screen in release mode
    if (!kDebugMode) {
      ErrorWidget.builder = _buildFallbackErrorWidget;
    }
  }

  /// Handles errors reported through [FlutterError.onError].
  static void _handleFlutterError(FlutterErrorDetails details) {
    // Req 6.3 — log error details
    _logger.e(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );

    // Req 6.4 — print full details in debug mode
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  /// Handles errors reported through [PlatformDispatcher.instance.onError].
  static bool _handlePlatformError(Object error, StackTrace stack) {
    // Req 6.3 — log error details
    _logger.e(
      'PlatformError: ${error.runtimeType} - $error',
      error: error,
      stackTrace: stack,
    );

    // Req 6.4 — print full details in debug mode
    if (kDebugMode) {
      debugPrint('Unhandled platform error: $error');
      debugPrint('$stack');
    }

    // Return true to indicate the error was handled
    return true;
  }

  /// Fallback widget shown in release mode instead of the red error screen.
  static Widget _buildFallbackErrorWidget(FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Something went wrong.\nPlease restart the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
