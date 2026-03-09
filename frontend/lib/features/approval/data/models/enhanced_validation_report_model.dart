import 'package:equatable/equatable.dart';

/// Enhanced validation report model
class EnhancedValidationReportModel extends Equatable {
  final ValidationSummaryModel summary;
  final List<ValidationCategoryModel> categories;
  final ConfidenceBreakdownModel confidenceBreakdown;
  final EnhancedRecommendationModel recommendation;
  final String detailedEvidence;

  const EnhancedValidationReportModel({
    required this.summary,
    required this.categories,
    required this.confidenceBreakdown,
    required this.recommendation,
    required this.detailedEvidence,
  });

  factory EnhancedValidationReportModel.fromJson(Map<String, dynamic> json) {
    return EnhancedValidationReportModel(
      summary: ValidationSummaryModel.fromJson(json['summary']),
      categories: (json['categories'] as List)
          .map((c) => ValidationCategoryModel.fromJson(c))
          .toList(),
      confidenceBreakdown:
          ConfidenceBreakdownModel.fromJson(json['confidenceBreakdown']),
      recommendation:
          EnhancedRecommendationModel.fromJson(json['recommendation']),
      detailedEvidence: json['detailedEvidence'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        summary,
        categories,
        confidenceBreakdown,
        recommendation,
        detailedEvidence,
      ];
}

/// Validation summary model
class ValidationSummaryModel extends Equatable {
  final int totalValidations;
  final int passedValidations;
  final int failedValidations;
  final int criticalIssues;
  final int highPriorityIssues;
  final int mediumPriorityIssues;
  final double overallConfidence;
  final String recommendationType;
  final String riskLevel;

  const ValidationSummaryModel({
    required this.totalValidations,
    required this.passedValidations,
    required this.failedValidations,
    required this.criticalIssues,
    required this.highPriorityIssues,
    required this.mediumPriorityIssues,
    required this.overallConfidence,
    required this.recommendationType,
    required this.riskLevel,
  });

  factory ValidationSummaryModel.fromJson(Map<String, dynamic> json) {
    return ValidationSummaryModel(
      totalValidations: json['totalValidations'] ?? 0,
      passedValidations: json['passedValidations'] ?? 0,
      failedValidations: json['failedValidations'] ?? 0,
      criticalIssues: json['criticalIssues'] ?? 0,
      highPriorityIssues: json['highPriorityIssues'] ?? 0,
      mediumPriorityIssues: json['mediumPriorityIssues'] ?? 0,
      overallConfidence: (json['overallConfidence'] ?? 0).toDouble(),
      recommendationType: json['recommendationType'] ?? '',
      riskLevel: json['riskLevel'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        totalValidations,
        passedValidations,
        failedValidations,
        criticalIssues,
        highPriorityIssues,
        mediumPriorityIssues,
        overallConfidence,
        recommendationType,
        riskLevel,
      ];
}

/// Validation category model
class ValidationCategoryModel extends Equatable {
  final String categoryName;
  final bool passed;
  final String severity;
  final String shortDescription;
  final ValidationDetailModel? details;

  const ValidationCategoryModel({
    required this.categoryName,
    required this.passed,
    required this.severity,
    required this.shortDescription,
    this.details,
  });

  factory ValidationCategoryModel.fromJson(Map<String, dynamic> json) {
    return ValidationCategoryModel(
      categoryName: json['categoryName'] ?? '',
      passed: json['passed'] ?? false,
      severity: json['severity'] ?? '',
      shortDescription: json['shortDescription'] ?? '',
      details: json['details'] != null
          ? ValidationDetailModel.fromJson(json['details'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
        categoryName,
        passed,
        severity,
        shortDescription,
        details,
      ];
}

/// Validation detail model
class ValidationDetailModel extends Equatable {
  final String description;
  final String expectedValue;
  final String actualValue;
  final String impact;
  final String suggestedAction;

  const ValidationDetailModel({
    required this.description,
    required this.expectedValue,
    required this.actualValue,
    required this.impact,
    required this.suggestedAction,
  });

  factory ValidationDetailModel.fromJson(Map<String, dynamic> json) {
    return ValidationDetailModel(
      description: json['description'] ?? '',
      expectedValue: json['expectedValue'] ?? '',
      actualValue: json['actualValue'] ?? '',
      impact: json['impact'] ?? '',
      suggestedAction: json['suggestedAction'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        description,
        expectedValue,
        actualValue,
        impact,
        suggestedAction,
      ];
}

/// Confidence breakdown model
class ConfidenceBreakdownModel extends Equatable {
  final List<DocumentConfidenceModel> documents;

  const ConfidenceBreakdownModel({
    required this.documents,
  });

  factory ConfidenceBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ConfidenceBreakdownModel(
      documents: (json['documents'] as List)
          .map((d) => DocumentConfidenceModel.fromJson(d))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [documents];
}

/// Document confidence model
class DocumentConfidenceModel extends Equatable {
  final String documentType;
  final double confidence;
  final double weight;
  final double weightedScore;

  const DocumentConfidenceModel({
    required this.documentType,
    required this.confidence,
    required this.weight,
    required this.weightedScore,
  });

  factory DocumentConfidenceModel.fromJson(Map<String, dynamic> json) {
    return DocumentConfidenceModel(
      documentType: json['documentType'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      weight: (json['weight'] ?? 0).toDouble(),
      weightedScore: (json['weightedScore'] ?? 0).toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        documentType,
        confidence,
        weight,
        weightedScore,
      ];
}

/// Enhanced recommendation model
class EnhancedRecommendationModel extends Equatable {
  final String action;
  final String reasoning;
  final List<IssueModel> criticalIssues;
  final List<IssueModel> highPriorityIssues;
  final List<IssueModel> mediumPriorityIssues;
  final String riskAssessment;

  const EnhancedRecommendationModel({
    required this.action,
    required this.reasoning,
    required this.criticalIssues,
    required this.highPriorityIssues,
    required this.mediumPriorityIssues,
    required this.riskAssessment,
  });

  factory EnhancedRecommendationModel.fromJson(Map<String, dynamic> json) {
    return EnhancedRecommendationModel(
      action: json['action'] ?? '',
      reasoning: json['reasoning'] ?? '',
      criticalIssues: (json['criticalIssues'] as List? ?? [])
          .map((i) => IssueModel.fromJson(i))
          .toList(),
      highPriorityIssues: (json['highPriorityIssues'] as List? ?? [])
          .map((i) => IssueModel.fromJson(i))
          .toList(),
      mediumPriorityIssues: (json['mediumPriorityIssues'] as List? ?? [])
          .map((i) => IssueModel.fromJson(i))
          .toList(),
      riskAssessment: json['riskAssessment'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        action,
        reasoning,
        criticalIssues,
        highPriorityIssues,
        mediumPriorityIssues,
        riskAssessment,
      ];
}

/// Issue model
class IssueModel extends Equatable {
  final String category;
  final String description;
  final String suggestedAction;

  const IssueModel({
    required this.category,
    required this.description,
    required this.suggestedAction,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      suggestedAction: json['suggestedAction'] ?? '',
    );
  }

  @override
  List<Object?> get props => [category, description, suggestedAction];
}
