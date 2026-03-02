import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/document_package.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_remote_datasource.dart';

/// Implementation of DocumentRepository
class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentRemoteDataSource remoteDataSource;

  DocumentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, DocumentPackage>> submitDocuments({
    required File? poFile,
    required File? invoiceFile,
    required File? costSummaryFile,
    required List<File> photoFiles,
    List<File>? additionalFiles,
  }) async {
    try {
      // Validate file formats and sizes
      final validationError = _validateFiles(
        poFile: poFile,
        invoiceFile: invoiceFile,
        costSummaryFile: costSummaryFile,
        photoFiles: photoFiles,
        additionalFiles: additionalFiles,
      );

      if (validationError != null) {
        return Left(ValidationFailure(validationError));
      }

      final result = await remoteDataSource.submitDocuments(
        poFile: poFile,
        invoiceFile: invoiceFile,
        costSummaryFile: costSummaryFile,
        photoFiles: photoFiles,
        additionalFiles: additionalFiles,
      );

      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DocumentPackage>> getSubmission(String id) async {
    try {
      final result = await remoteDataSource.getSubmission(id);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DocumentPackage>>> getSubmissions({
    String? state,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final result = await remoteDataSource.getSubmissions(
        state: state,
        page: page,
        pageSize: pageSize,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  String? _validateFiles({
    required File? poFile,
    required File? invoiceFile,
    required File? costSummaryFile,
    required List<File> photoFiles,
    List<File>? additionalFiles,
  }) {
    // Validate PO file
    if (poFile != null) {
      if (!poFile.path.toLowerCase().endsWith('.pdf')) {
        return 'PO must be a PDF file';
      }
      if (poFile.lengthSync() > 10 * 1024 * 1024) {
        return 'PO file size must be less than 10MB';
      }
    }

    // Validate Invoice file
    if (invoiceFile != null) {
      if (!invoiceFile.path.toLowerCase().endsWith('.pdf')) {
        return 'Invoice must be a PDF file';
      }
      if (invoiceFile.lengthSync() > 10 * 1024 * 1024) {
        return 'Invoice file size must be less than 10MB';
      }
    }

    // Validate Cost Summary file
    if (costSummaryFile != null) {
      if (!costSummaryFile.path.toLowerCase().endsWith('.pdf')) {
        return 'Cost Summary must be a PDF file';
      }
      if (costSummaryFile.lengthSync() > 10 * 1024 * 1024) {
        return 'Cost Summary file size must be less than 10MB';
      }
    }

    // Validate photos
    for (var photo in photoFiles) {
      final ext = photo.path.toLowerCase();
      if (!ext.endsWith('.jpg') && !ext.endsWith('.jpeg') && !ext.endsWith('.png')) {
        return 'Photos must be JPG or PNG files';
      }
      if (photo.lengthSync() > 5 * 1024 * 1024) {
        return 'Photo file size must be less than 5MB';
      }
    }

    // Validate additional files
    if (additionalFiles != null) {
      for (var file in additionalFiles) {
        if (!file.path.toLowerCase().endsWith('.pdf')) {
          return 'Additional documents must be PDF files';
        }
        if (file.lengthSync() > 10 * 1024 * 1024) {
          return 'Additional file size must be less than 10MB';
        }
      }
    }

    return null;
  }
}
