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
  final List<DealerItemModel>? dealers;
  final TeamContextModel? teamContext;
  final String? payloadJson;
  final List<PhotoValidationResultModel>? photoResults;
  final List<TeamSummaryItemModel>? teamSummaries;
  final int? totalRecords;
  final int? missingPhoneCount;
  final List<FinalReviewSectionModel>? reviewSections;
  final String? fileName;
  final List<PendingClaimItemModel>? pendingClaims;

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
    this.dealers,
    this.teamContext,
    this.payloadJson,
    this.photoResults,
    this.teamSummaries,
    this.totalRecords,
    this.missingPhoneCount,
    this.reviewSections,
    this.fileName,
    this.pendingClaims,
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
      dealers: (json['dealers'] as List<dynamic>?)
          ?.map((e) => DealerItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      teamContext: json['teamContext'] != null
          ? TeamContextModel.fromJson(json['teamContext'] as Map<String, dynamic>)
          : null,
      payloadJson: json['payloadJson'] as String?,
      photoResults: (json['photoResults'] as List<dynamic>?)
          ?.map((e) => PhotoValidationResultModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      teamSummaries: (json['teamSummaries'] as List<dynamic>?)
          ?.map((e) => TeamSummaryItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalRecords: json['totalRecords'] as int?,
      missingPhoneCount: json['missingPhoneCount'] as int?,
      reviewSections: (json['reviewSections'] as List<dynamic>?)
          ?.map((e) => FinalReviewSectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      fileName: json['fileName'] as String?,
      pendingClaims: (json['pendingClaims'] as List<dynamic>?)
          ?.map((e) => PendingClaimItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
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

class DealerItemModel {
  final String dealerCode;
  final String dealerName;
  final String city;
  final String state;

  const DealerItemModel({
    required this.dealerCode,
    required this.dealerName,
    required this.city,
    required this.state,
  });

  factory DealerItemModel.fromJson(Map<String, dynamic> json) {
    return DealerItemModel(
      dealerCode: json['dealerCode'] as String? ?? '',
      dealerName: json['dealerName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
    );
  }
}

class TeamContextModel {
  final int currentTeam;
  final int totalTeams;
  final String? teamName;

  const TeamContextModel({required this.currentTeam, required this.totalTeams, this.teamName});

  factory TeamContextModel.fromJson(Map<String, dynamic> json) {
    return TeamContextModel(
      currentTeam: json['currentTeam'] as int? ?? 1,
      totalTeams: json['totalTeams'] as int? ?? 1,
      teamName: json['teamName'] as String?,
    );
  }
}

class PhotoValidationResultModel {
  final String photoId;
  final int displayOrder;
  final String fileName;
  final List<ValidationRuleResultModel> rules;
  final bool allPassed;

  const PhotoValidationResultModel({
    required this.photoId,
    required this.displayOrder,
    required this.fileName,
    required this.rules,
    required this.allPassed,
  });

  factory PhotoValidationResultModel.fromJson(Map<String, dynamic> json) {
    return PhotoValidationResultModel(
      photoId: json['photoId'] as String? ?? '',
      displayOrder: json['displayOrder'] as int? ?? 0,
      fileName: json['fileName'] as String? ?? '',
      rules: (json['rules'] as List<dynamic>?)
              ?.map((e) => ValidationRuleResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      allPassed: json['allPassed'] as bool? ?? false,
    );
  }
}

class TeamSummaryItemModel {
  final int teamNumber;
  final String teamName;
  final String dealerName;
  final String city;
  final String state;
  final String startDate;
  final String endDate;
  final int workingDays;
  final int photoCount;
  final int photosPassed;

  const TeamSummaryItemModel({
    required this.teamNumber,
    required this.teamName,
    required this.dealerName,
    required this.city,
    required this.state,
    required this.startDate,
    required this.endDate,
    required this.workingDays,
    required this.photoCount,
    required this.photosPassed,
  });

  factory TeamSummaryItemModel.fromJson(Map<String, dynamic> json) {
    return TeamSummaryItemModel(
      teamNumber: json['teamNumber'] as int? ?? 0,
      teamName: json['teamName'] as String? ?? '',
      dealerName: json['dealerName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      workingDays: json['workingDays'] as int? ?? 0,
      photoCount: json['photoCount'] as int? ?? 0,
      photosPassed: json['photosPassed'] as int? ?? 0,
    );
  }
}

class FinalReviewSectionModel {
  final String title;
  final String icon;
  final bool passed;
  final List<FinalReviewFieldModel> fields;

  const FinalReviewSectionModel({
    required this.title,
    required this.icon,
    required this.passed,
    required this.fields,
  });

  factory FinalReviewSectionModel.fromJson(Map<String, dynamic> json) {
    return FinalReviewSectionModel(
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? 'info',
      passed: json['passed'] as bool? ?? true,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => FinalReviewFieldModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FinalReviewFieldModel {
  final String label;
  final String value;

  const FinalReviewFieldModel({required this.label, required this.value});

  factory FinalReviewFieldModel.fromJson(Map<String, dynamic> json) {
    return FinalReviewFieldModel(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '—',
    );
  }
}

class PendingClaimItemModel {
  final String submissionId;
  final String fapId;
  final String poNumber;
  final double invoiceAmount;
  final String status;
  final String statusLabel;
  final String statusColor;
  final String submittedDate;
  final String activityState;

  const PendingClaimItemModel({
    required this.submissionId,
    required this.fapId,
    required this.poNumber,
    required this.invoiceAmount,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.submittedDate,
    required this.activityState,
  });

  factory PendingClaimItemModel.fromJson(Map<String, dynamic> json) {
    return PendingClaimItemModel(
      submissionId: json['submissionId'] as String? ?? '',
      fapId: json['fapId'] as String? ?? '',
      poNumber: json['poNumber'] as String? ?? '—',
      invoiceAmount: (json['invoiceAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
      statusColor: json['statusColor'] as String? ?? 'blue',
      submittedDate: json['submittedDate'] as String? ?? '',
      activityState: json['activityState'] as String? ?? '—',
    );
  }
}
