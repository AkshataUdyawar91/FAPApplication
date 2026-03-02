import '../../domain/entities/validation_result.dart';

class ValidationResultModel extends ValidationResult {
  const ValidationResultModel({
    required super.id,
    required super.packageId,
    required super.passed,
    required super.issues,
    required super.validatedAt,
  });

  factory ValidationResultModel.fromJson(Map<String, dynamic> json) {
    return ValidationResultModel(
      id: json['id'] as String,
      packageId: json['packageId'] as String,
      passed: json['passed'] as bool,
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => ValidationIssueModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      validatedAt: DateTime.parse(json['validatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageId': packageId,
      'passed': passed,
      'issues': issues.map((e) => (e as ValidationIssueModel).toJson()).toList(),
      'validatedAt': validatedAt.toIso8601String(),
    };
  }
}

class ValidationIssueModel extends ValidationIssue {
  const ValidationIssueModel({
    required super.field,
    required super.message,
    super.expectedValue,
    super.actualValue,
  });

  factory ValidationIssueModel.fromJson(Map<String, dynamic> json) {
    return ValidationIssueModel(
      field: json['field'] as String,
      message: json['message'] as String,
      expectedValue: json['expectedValue'] as String?,
      actualValue: json['actualValue'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'message': message,
      'expectedValue': expectedValue,
      'actualValue': actualValue,
    };
  }
}
