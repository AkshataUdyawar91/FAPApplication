import '../../domain/entities/conversation_message.dart';
import 'po_search_result_model.dart';
import 'validation_result_model.dart';

/// Base card data model with JSON deserialization factory.
class CardDataModel extends CardData {
  const CardDataModel({required super.type});

  factory CardDataModel.fromJson(Map<String, dynamic> json) {
    final type = json['cardType'] as String? ?? json['type'] as String? ?? 'unknown';
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

  Map<String, dynamic> toJson() {
    return {'type': type};
  }
}

/// Card displaying a list of POs for selection.
class POListCardModel extends CardDataModel {
  final List<POSearchResultModel> purchaseOrders;

  const POListCardModel({required this.purchaseOrders})
      : super(type: 'poList');

  factory POListCardModel.fromJson(Map<String, dynamic> json) {
    return POListCardModel(
      purchaseOrders: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  POSearchResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'purchaseOrders': purchaseOrders.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [type, purchaseOrders];
}

/// Card displaying per-document validation results.
class ValidationResultCardModel extends CardDataModel {
  final String documentId;
  final String documentType;
  final bool allPassed;
  final int passCount;
  final int failCount;
  final int warningCount;
  final List<ValidationResultModel> rules;

  const ValidationResultCardModel({
    required this.documentId,
    required this.documentType,
    required this.allPassed,
    required this.passCount,
    required this.failCount,
    required this.warningCount,
    required this.rules,
  }) : super(type: 'validationResult');

  factory ValidationResultCardModel.fromJson(Map<String, dynamic> json) {
    return ValidationResultCardModel(
      documentId: json['documentId'] as String,
      documentType: json['documentType'] as String,
      allPassed: json['allPassed'] as bool,
      passCount: json['passCount'] as int,
      failCount: json['failCount'] as int,
      warningCount: json['warningCount'] as int,
      rules: (json['rules'] as List<dynamic>?)
              ?.map((e) =>
                  ValidationResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'documentId': documentId,
      'documentType': documentType,
      'allPassed': allPassed,
      'passCount': passCount,
      'failCount': failCount,
      'warningCount': warningCount,
      'rules': rules.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        type,
        documentId,
        documentType,
        allPassed,
        passCount,
        failCount,
        warningCount,
        rules,
      ];
}

/// Card displaying team details summary.
class TeamSummaryCardModel extends CardDataModel {
  final List<Map<String, dynamic>> teams;

  const TeamSummaryCardModel({required this.teams})
      : super(type: 'teamSummary');

  factory TeamSummaryCardModel.fromJson(Map<String, dynamic> json) {
    return TeamSummaryCardModel(
      teams: (json['teams'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'teams': teams,
    };
  }

  @override
  List<Object?> get props => [type, teams];
}

/// Card displaying the comprehensive final review before submission.
class FinalReviewCardModel extends CardDataModel {
  final Map<String, dynamic> summary;

  const FinalReviewCardModel({required this.summary})
      : super(type: 'finalReview');

  factory FinalReviewCardModel.fromJson(Map<String, dynamic> json) {
    return FinalReviewCardModel(
      summary: Map<String, dynamic>.from(
          json['summary'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'summary': summary,
    };
  }

  @override
  List<Object?> get props => [type, summary];
}
