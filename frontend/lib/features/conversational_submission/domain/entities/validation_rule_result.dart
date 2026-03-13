import 'package:equatable/equatable.dart';

/// Severity of a validation rule result.
enum ValidationSeverity { pass, fail, warning }

/// A single proactive validation rule result for a document.
class ValidationRuleResult extends Equatable {
  final String ruleCode;
  final String type;
  final bool passed;
  final String? extractedValue;
  final String? expectedValue;
  final String? message;
  final ValidationSeverity severity;

  const ValidationRuleResult({
    required this.ruleCode,
    required this.type,
    required this.passed,
    this.extractedValue,
    this.expectedValue,
    this.message,
    required this.severity,
  });

  @override
  List<Object?> get props => [
        ruleCode,
        type,
        passed,
        extractedValue,
        expectedValue,
        message,
        severity,
      ];
}
