import 'package:equatable/equatable.dart';

import '../enums/validation_type.dart';

/// Represents a single validation error for a captured photo.
class ValidationError extends Equatable {
  /// The type of validation failure.
  final ValidationType type;

  /// A user-friendly error message.
  final String message;

  const ValidationError({
    required this.type,
    required this.message,
  });

  @override
  List<Object?> get props => [type, message];
}

/// Represents the result of validating a captured photo.
class ValidationResult extends Equatable {
  /// Whether the photo passed all validation checks.
  final bool isValid;

  /// List of validation errors (empty if valid).
  final List<ValidationError> errors;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  @override
  List<Object?> get props => [isValid, errors];
}
