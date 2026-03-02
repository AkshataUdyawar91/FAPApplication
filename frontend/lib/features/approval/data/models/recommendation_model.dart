import '../../domain/entities/recommendation.dart';

class RecommendationModel extends Recommendation {
  const RecommendationModel({
    required super.id,
    required super.packageId,
    required super.type,
    required super.evidence,
    required super.createdAt,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      id: json['id'] as String,
      packageId: json['packageId'] as String,
      type: _parseRecommendationType(json['type'] as String),
      evidence: json['evidence'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageId': packageId,
      'type': _recommendationTypeToString(type),
      'evidence': evidence,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static RecommendationType _parseRecommendationType(String type) {
    switch (type.toLowerCase()) {
      case 'approve':
        return RecommendationType.approve;
      case 'review':
        return RecommendationType.review;
      case 'reject':
        return RecommendationType.reject;
      default:
        return RecommendationType.review;
    }
  }

  static String _recommendationTypeToString(RecommendationType type) {
    switch (type) {
      case RecommendationType.approve:
        return 'approve';
      case RecommendationType.review:
        return 'review';
      case RecommendationType.reject:
        return 'reject';
    }
  }
}
