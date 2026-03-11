import 'package:equatable/equatable.dart';

import '../enums/camera_error_type.dart';

/// Represents an error that occurred during a camera operation.
class CameraError extends Equatable implements Exception {
  /// The type of camera error.
  final CameraErrorType type;

  /// A user-friendly error message.
  final String message;

  /// Optional technical details for logging.
  final String? details;

  const CameraError({
    required this.type,
    required this.message,
    this.details,
  });

  @override
  List<Object?> get props => [type, message, details];
}
