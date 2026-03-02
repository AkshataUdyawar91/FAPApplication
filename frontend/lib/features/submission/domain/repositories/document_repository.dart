import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/document_package.dart';

/// Document repository interface
abstract class DocumentRepository {
  /// Submit documents
  Future<Either<Failure, DocumentPackage>> submitDocuments({
    required File? poFile,
    required File? invoiceFile,
    required File? costSummaryFile,
    required List<File> photoFiles,
    List<File>? additionalFiles,
  });

  /// Get submission by ID
  Future<Either<Failure, DocumentPackage>> getSubmission(String id);

  /// Get all submissions for current user
  Future<Either<Failure, List<DocumentPackage>>> getSubmissions({
    String? state,
    int page = 1,
    int pageSize = 20,
  });
}
