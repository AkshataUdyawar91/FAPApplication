import '../../domain/entities/validation_rule_result.dart';

/// Data model for ValidationRuleResult with JSON serialization.
class ValidationResultModel extends ValidationRuleResult {
  const ValidationResultModel({
    required super.ruleCode,
    required super.type,
    required super.passed,
    super.extractedValue,
    super.expectedValue,
    super.message,
    required super.severity,
  });

  factory ValidationResultModel.fromJson(Map<String, dynamic> json) {
    return ValidationResultModel(
      ruleCode: json['ruleCode'] as String,
      type: json['type'] as String,
      passed: json['passed'] as bool,
      extractedValue: json['extractedValue'] as String?,
      expectedValue: json['expectedValue'] as String?,
      message: json['message'] as String?,
      severity: _parseSeverity(json['severity'] as String?),
    );
  }

  static ValidationSeverity _parseSeverity(String? value) {
    switch (value?.toLowerCase()) {
      case 'pass':
        return ValidationSeverity.pass;
      case 'fail':
        return ValidationSeverity.fail;
      case 'warning':
        return ValidationSeverity.warning;
      default:
        return ValidationSeverity.pass;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ruleCode': ruleCode,
      'type': type,
      'passed': passed,
      if (extractedValue != null) 'extractedValue': extractedValue,
      if (expectedValue != null) 'expectedValue': expectedValue,
      if (message != null) 'message': message,
      'severity': severity.name,
    };
  }
}
