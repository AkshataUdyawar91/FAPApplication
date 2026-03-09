import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/document_package.dart';
import '../repositories/document_repository.dart';

/// Use case for submitting documents
class SubmitDocumentsUseCase {
  final DocumentRepository repository;

  const SubmitDocumentsUseCase(this.repository);

  Future<Either<Failure, DocumentPackage>> call({
    required File? poFile,
    required File? invoiceFile,
    required File? costSummaryFile,
    required List<File> photoFiles,
    List<File>? additionalFiles,
  }) async {
    // Validate required documents
    if (poFile == null || invoiceFile == null || costSummaryFile == null) {
      return Left(ValidationFailure('All required documents must be provided'));
    }

    // Validate photo count
    if (photoFiles.isEmpty) {
      return Left(ValidationFailure('At least one photo is required'));
    }

    // CHANGE: Increased photo limit from 20 to 50
    if (photoFiles.length > 50) {
      return Left(ValidationFailure('Maximum 50 photos allowed'));
    }

    return await repository.submitDocuments(
      poFile: poFile,
      invoiceFile: invoiceFile,
      costSummaryFile: costSummaryFile,
      photoFiles: photoFiles,
      additionalFiles: additionalFiles,
    );
  }
}
