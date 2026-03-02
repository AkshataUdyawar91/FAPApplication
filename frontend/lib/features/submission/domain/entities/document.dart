import 'package:equatable/equatable.dart';

/// Document entity
class Document extends Equatable {
  final String id;
  final String packageId;
  final String type;
  final String fileName;
  final String blobUrl;
  final int fileSize;
  final double? classificationConfidence;
  final double? extractionConfidence;
  final Map<String, dynamic>? extractedData;

  const Document({
    required this.id,
    required this.packageId,
    required this.type,
    required this.fileName,
    required this.blobUrl,
    required this.fileSize,
    this.classificationConfidence,
    this.extractionConfidence,
    this.extractedData,
  });

  @override
  List<Object?> get props => [
        id,
        packageId,
        type,
        fileName,
        blobUrl,
        fileSize,
        classificationConfidence,
        extractionConfidence,
        extractedData,
      ];
}
