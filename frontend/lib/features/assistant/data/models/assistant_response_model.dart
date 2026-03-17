/// Response from the assistant backend.
class AssistantResponseModel {
  final String type;
  final String message;
  final List<WorkflowCardModel>? cards;
  final List<POItemModel>? poItems;
  final POItemModel? selectedPO;
  final List<String>? allowedFormats;
  final List<String>? states;
  final String? inputHint;
  final int? minSearchLength;
  final String? submissionId;
  final List<ValidationRuleResultModel>? validationRules;
  final int? passedCount;
  final int? failedCount;
  final int? warningCount;

  const AssistantResponseModel({
    required this.type,
    required this.message,
    this.cards,
    this.poItems,
    this.selectedPO,
    this.allowedFormats,
    this.states,
    this.inputHint,
    this.minSearchLength,
    this.submissionId,
    this.validationRules,
    this.passedCount,
    this.failedCount,
    this.warningCount,
  });

  factory AssistantResponseModel.fromJson(Map<String, dynamic> json) {
    return AssistantResponseModel(
      type: json['type'] as String? ?? 'text',
      message: json['message'] as String? ?? '',
      cards: (json['cards'] as List<dynamic>?)
          ?.map((e) => WorkflowCardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      poItems: (json['poItems'] as List<dynamic>?)
          ?.map((e) => POItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedPO: json['selectedPO'] != null
          ? POItemModel.fromJson(json['selectedPO'] as Map<String, dynamic>)
          : null,
      allowedFormats: (json['allowedFormats'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      states: (json['states'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      inputHint: json['inputHint'] as String?,
      minSearchLength: json['minSearchLength'] as int?,
      submissionId: json['submissionId'] as String?,
      validationRules: (json['validationRules'] as List<dynamic>?)
          ?.map((e) => ValidationRuleResultModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      passedCount: json['passedCount'] as int?,
      failedCount: json['failedCount'] as int?,
      warningCount: json['warningCount'] as int?,
    );
  }
}

class WorkflowCardModel {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String action;

  const WorkflowCardModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
  });

  factory WorkflowCardModel.fromJson(Map<String, dynamic> json) {
    return WorkflowCardModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: json['icon'] as String? ?? 'help_outline',
      action: json['action'] as String? ?? '',
    );
  }
}

class POItemModel {
  final String id;
  final String poNumber;
  final DateTime poDate;
  final String vendorName;
  final double totalAmount;
  final double? remainingBalance;
  final String poStatus;

  const POItemModel({
    required this.id,
    required this.poNumber,
    required this.poDate,
    required this.vendorName,
    required this.totalAmount,
    this.remainingBalance,
    required this.poStatus,
  });

  factory POItemModel.fromJson(Map<String, dynamic> json) {
    return POItemModel(
      id: json['id'] as String,
      poNumber: json['poNumber'] as String,
      poDate: DateTime.parse(json['poDate'] as String),
      vendorName: json['vendorName'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainingBalance: (json['remainingBalance'] as num?)?.toDouble(),
      poStatus: json['poStatus'] as String? ?? 'Unknown',
    );
  }
}

class ValidationRuleResultModel {
  final String ruleCode;
  final String type;
  final bool passed;
  final bool isWarning;
  final String label;
  final String? extractedValue;
  final String? message;

  const ValidationRuleResultModel({
    required this.ruleCode,
    required this.type,
    required this.passed,
    required this.isWarning,
    required this.label,
    this.extractedValue,
    this.message,
  });

  factory ValidationRuleResultModel.fromJson(Map<String, dynamic> json) {
    return ValidationRuleResultModel(
      ruleCode: json['ruleCode'] as String? ?? '',
      type: json['type'] as String? ?? 'Required',
      passed: json['passed'] as bool? ?? false,
      isWarning: json['isWarning'] as bool? ?? false,
      label: json['label'] as String? ?? '',
      extractedValue: json['extractedValue'] as String?,
      message: json['message'] as String?,
    );
  }
}
