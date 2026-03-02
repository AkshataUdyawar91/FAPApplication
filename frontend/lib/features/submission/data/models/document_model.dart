import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/document.dart';

part 'document_model.g.dart';

/// Document model with JSON serialization
@JsonSerializable()
class DocumentModel extends Document {
  const DocumentModel({
    required super.id,
    required super.packageId,
    required super.type,
    required super.fileName,
    required super.blobUrl,
    required super.fileSize,
    super.classificationConfidence,
    super.extractionConfidence,
    super.extractedData,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) =>
      _$DocumentModelFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentModelToJson(this);
}
