import 'package:equatable/equatable.dart';
import 'document.dart';

/// Document package entity
class DocumentPackage extends Equatable {
  final String id;
  final String userId;
  final String state;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Document> documents;

  const DocumentPackage({
    required this.id,
    required this.userId,
    required this.state,
    required this.createdAt,
    this.updatedAt,
    this.documents = const [],
  });

  @override
  List<Object?> get props => [id, userId, state, createdAt, updatedAt, documents];
}
