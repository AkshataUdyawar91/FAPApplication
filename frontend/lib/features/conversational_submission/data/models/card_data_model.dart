import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/validation_rule_result.dart';
import 'po_search_result_model.dart';
import 'validation_result_model.dart';

/// Base card data model with JSON deserialization factory.
class CardDataModel extends CardData {
  const CardDataModel({required super.type});

  factory CardDataModel.fromJson(Map<String, dynamic> json) {
    final type =
        json['cardType'] as String? ?? json['type'] as String? ?? 'unknown';
    switch (type) {
      case 'poList':
        return POListCardModel.fromJson(json);
      case 'validationResult':
        return ValidationResultCardModel.fromJson(json);
      case 'teamSummary':
        return TeamSummaryCardModel.fromJson(json);
      case 'finalReview':
        return FinalReviewCardModel.fromJson(json);
      default:
        return CardDataModel(type: type);
    }
  }

  Map<String, dynamic> toJson() => {'type': type};
}

/// Card displaying a list of POs for selection.
class POListCardModel extends CardDataModel {
  final List<POSearchResultModel> purchaseOrders;

  const POListCardModel({required this.purchaseOrders})
      : super(type: 'poList');

  factory POListCardModel.fromJson(Map<String, dynamic> json) {
    return POListCardModel(
      purchaseOrders: (json['items'] as List<dynamic>?)
              ?.map(
                  (e) => POSearchResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'purchaseOrders': purchaseOrders.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [type, purchaseOrders];
}

/// Card displaying per-document validation results.
/// Backend sends: documentType, allPassed, rules[]. Counts computed from rules.
class ValidationResultCardModel extends CardDataModel {
  final String documentType;
  final bool allPassed;
  final List<ValidationResultModel> rules;

  const ValidationResultCardModel({
    required this.documentType,
    required this.allPassed,
    required this.rules,
  }) : super(type: 'validationResult');

  int get passCount => rules.where((r) => r.passed).length;
  int get failCount =>
      rules.where((r) => !r.passed && r.severity != ValidationSeverity.warning).length;
  int get warningCount =>
      rules.where((r) => !r.passed && r.severity == ValidationSeverity.warning).length;

  factory ValidationResultCardModel.fromJson(Map<String, dynamic> json) {
    return ValidationResultCardModel(
      documentType: json['documentType'] as String? ?? 'Unknown',
      allPassed: json['allPassed'] as bool? ?? false,
      rules: (json['rules'] as List<dynamic>?)
              ?.map((e) =>
                  ValidationResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'documentType': documentType,
        'allPassed': allPassed,
        'rules': rules.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [type, documentType, allPassed, rules];
}

/// Card displaying team details summary.
/// Backend sends flat fields per team.
class TeamSummaryCardModel extends CardDataModel {
  final String teamName;
  final String dealerName;
  final String city;
  final String startDate;
  final String endDate;
  final int workingDays;
  final int photoCount;
  final int photosValidated;

  const TeamSummaryCardModel({
    required this.teamName,
    required this.dealerName,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.workingDays,
    required this.photoCount,
    required this.photosValidated,
  }) : super(type: 'teamSummary');

  factory TeamSummaryCardModel.fromJson(Map<String, dynamic> json) {
    return TeamSummaryCardModel(
      teamName: json['teamName'] as String? ?? '',
      dealerName: json['dealerName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      workingDays: json['workingDays'] as int? ?? 0,
      photoCount: json['photoCount'] as int? ?? 0,
      photosValidated: json['photosValidated'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'teamName': teamName,
        'dealerName': dealerName,
        'city': city,
        'startDate': startDate,
        'endDate': endDate,
        'workingDays': workingDays,
        'photoCount': photoCount,
        'photosValidated': photosValidated,
      };

  @override
  List<Object?> get props => [
        type, teamName, dealerName, city, startDate, endDate,
        workingDays, photoCount, photosValidated,
      ];
}

/// Card displaying the comprehensive final review before submission.
/// Backend sends typed fields matching FinalReviewCard DTO.
class FinalReviewCardModel extends CardDataModel {
  final String poNumber;
  final String state;
  final String invoiceStatus;
  final String costSummaryStatus;
  final String activitySummaryStatus;
  final List<TeamSummaryCardModel> teams;
  final int enquiryRecordCount;
  final double totalAmount;

  const FinalReviewCardModel({
    required this.poNumber,
    required this.state,
    required this.invoiceStatus,
    required this.costSummaryStatus,
    required this.activitySummaryStatus,
    required this.teams,
    required this.enquiryRecordCount,
    required this.totalAmount,
  }) : super(type: 'finalReview');

  factory FinalReviewCardModel.fromJson(Map<String, dynamic> json) {
    return FinalReviewCardModel(
      poNumber: json['poNumber'] as String? ?? '',
      state: json['state'] as String? ?? '',
      invoiceStatus: json['invoiceStatus'] as String? ?? '',
      costSummaryStatus: json['costSummaryStatus'] as String? ?? '',
      activitySummaryStatus: json['activitySummaryStatus'] as String? ?? '',
      teams: (json['teams'] as List<dynamic>?)
              ?.map((e) =>
                  TeamSummaryCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      enquiryRecordCount: json['enquiryRecordCount'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'poNumber': poNumber,
        'state': state,
        'invoiceStatus': invoiceStatus,
        'costSummaryStatus': costSummaryStatus,
        'activitySummaryStatus': activitySummaryStatus,
        'teams': teams.map((e) => e.toJson()).toList(),
        'enquiryRecordCount': enquiryRecordCount,
        'totalAmount': totalAmount,
      };

  @override
  List<Object?> get props => [
        type, poNumber, state, invoiceStatus, costSummaryStatus,
        activitySummaryStatus, teams, enquiryRecordCount, totalAmount,
      ];
}
