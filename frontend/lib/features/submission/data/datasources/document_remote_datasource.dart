import 'dart:io';
import 'package:dio/dio.dart';
import '../models/document_package_model.dart';

/// Remote data source for documents
abstract class DocumentRemoteDataSource {
  Future<DocumentPackageModel> submitDocuments({
    required File? poFile,
    required File? invoiceFile,
    required File? costSummaryFile,
    required List<File> photoFiles,
    List<File>? additionalFiles,
  });

  Future<DocumentPackageModel> getSubmission(String id);

  Future<List<DocumentPackageModel>> getSubmissions({
    String? state,
    int page = 1,
    int pageSize = 20,
  });
}

class DocumentRemoteDataSourceImpl implements DocumentRemoteDataSource {
  final Dio dio;

  DocumentRemoteDataSourceImpl(this.dio);

  @override
  Future<DocumentPackageModel> submitDocuments({
    required File? poFile,
    required File? invoiceFile,
    required File? costSummaryFile,
    required List<File> photoFiles,
    List<File>? additionalFiles,
  }) async {
    try {
      // First, upload files to get URLs
      final formData = FormData();

      if (poFile != null) {
        formData.files.add(MapEntry(
          'po',
          await MultipartFile.fromFile(poFile.path, filename: 'po.pdf'),
        ));
      }

      if (invoiceFile != null) {
        formData.files.add(MapEntry(
          'invoice',
          await MultipartFile.fromFile(invoiceFile.path, filename: 'invoice.pdf'),
        ));
      }

      if (costSummaryFile != null) {
        formData.files.add(MapEntry(
          'costSummary',
          await MultipartFile.fromFile(costSummaryFile.path, filename: 'cost_summary.pdf'),
        ));
      }

      for (var i = 0; i < photoFiles.length; i++) {
        formData.files.add(MapEntry(
          'photos',
          await MultipartFile.fromFile(photoFiles[i].path, filename: 'photo_$i.jpg'),
        ));
      }

      if (additionalFiles != null) {
        for (var i = 0; i < additionalFiles.length; i++) {
          formData.files.add(MapEntry(
            'additional',
            await MultipartFile.fromFile(additionalFiles[i].path, filename: 'additional_$i.pdf'),
          ));
        }
      }

      // Upload documents
      final uploadResponse = await dio.post('/documents/upload', data: formData);

      // Create submission
      final submissionResponse = await dio.post('/submissions');

      if (submissionResponse.statusCode == 201) {
        return DocumentPackageModel.fromJson(submissionResponse.data);
      } else {
        throw Exception('Submission failed');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  Future<DocumentPackageModel> getSubmission(String id) async {
    try {
      final response = await dio.get('/submissions/$id');

      if (response.statusCode == 200) {
        return DocumentPackageModel.fromJson(response.data);
      } else {
        throw Exception('Failed to get submission');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  Future<List<DocumentPackageModel>> getSubmissions({
    String? state,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'pageSize': pageSize,
        if (state != null) 'state': state,
      };

      final response = await dio.get('/submissions', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final items = response.data['items'] as List;
        return items.map((json) => DocumentPackageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get submissions');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}
