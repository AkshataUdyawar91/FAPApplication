import 'package:equatable/equatable.dart';

class ValidationResult extends Equatable {
  final String id;
  final String packageId;
  final bool passed;
  final List<ValidationIssue> issues;
  final DateTime validatedAt;

  const ValidationResult({
    required this.id,
    required this.packageId,
    required this.passed,
    required this.issues,
    required this.validatedAt,
  });

  @override
  List<Object?> get props => [id, packageId, passed, issues, validatedAt];
}

class ValidationIssue extends Equatable {
  final String field;
  final String message;
  final String? expectedValue;
  final String? actualValue;

  const ValidationIssue({
    required this.field,
    required this.message,
    this.expectedValue,
    this.actualValue,
  });

  @override
  List<Object?> get props => [field, message, expectedValue, actualValue];
}
