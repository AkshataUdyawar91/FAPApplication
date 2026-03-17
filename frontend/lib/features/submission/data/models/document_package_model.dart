import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/document_package.dart';
import 'document_model.dart';

part 'document_package_model.g.dart';

/// Document package model with JSON serialization
@JsonSerializable(explicitToJson: true)
class DocumentPackageModel extends DocumentPackage {
  @override
  @JsonKey(name: 'documents')
  final List<DocumentModel> documents;

  const DocumentPackageModel({
    required super.id,
    required super.userId,
    required super.state,
    required super.createdAt,
    super.updatedAt,
    this.documents = const [],
  }) : super(documents: documents);

  factory DocumentPackageModel.fromJson(Map<String, dynamic> json) =>
      _$DocumentPackageModelFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentPackageModelToJson(this);

  factory DocumentPackageModel.fromEntity(DocumentPackage package) {
    return DocumentPackageModel(
      id: package.id,
      userId: package.userId,
      state: package.state,
      createdAt: package.createdAt,
      updatedAt: package.updatedAt,
      documents: package.documents.map((doc) {
        if (doc is DocumentModel) return doc;
        return DocumentModel(
          id: doc.id,
          packageId: doc.packageId,
          type: doc.type,
          fileName: doc.fileName,
          blobUrl: doc.blobUrl,
          fileSize: doc.fileSize,
          classificationConfidence: doc.classificationConfidence,
          extractionConfidence: doc.extractionConfidence,
          extractedData: doc.extractedData,
        );
      }).toList(),
    );
  }
}
