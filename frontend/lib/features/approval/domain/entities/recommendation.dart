import 'package:equatable/equatable.dart';

enum RecommendationType {
  approve,
  review,
  reject,
}

class Recommendation extends Equatable {
  final String id;
  final String packageId;
  final RecommendationType type;
  final String evidence;
  final DateTime createdAt;

  const Recommendation({
    required this.id,
    required this.packageId,
    required this.type,
    required this.evidence,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, packageId, type, evidence, createdAt];
}
