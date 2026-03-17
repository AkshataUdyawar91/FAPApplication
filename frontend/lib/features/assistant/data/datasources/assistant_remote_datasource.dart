import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/assistant_response_model.dart';

/// Remote datasource for the assistant API.
class AssistantRemoteDataSource {
  final Dio dio;

  const AssistantRemoteDataSource(this.dio);

  /// Send a message/action to the assistant.
  Future<AssistantResponseModel> sendMessage({
    required String action,
    String? message,
    String? payloadJson,
  }) async {
    final response = await dio.post(
      '/assistant/message',
      data: {
        'action': action,
        if (message != null) 'message': message,
        if (payloadJson != null) 'payloadJson': payloadJson,
      },
    );
    return AssistantResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Upload a PO document.
  Future<AssistantResponseModel> uploadPO({
    required Uint8List fileBytes,
    required String fileName,
    Guid? submissionId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      if (submissionId != null) 'submissionId': submissionId,
    });
    final response = await dio.post('/upload/po', data: formData);
    return AssistantResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Upload an invoice document to the documents endpoint.
  Future<Map<String, dynamic>> uploadInvoice({
    required Uint8List fileBytes,
    required String fileName,
    required String submissionId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'documentType': 'Invoice',
      'submissionId': submissionId,
    });
    final response = await dio.post('/documents/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'));
    return response.data as Map<String, dynamic>;
  }

  /// Upload an activity summary document.
  Future<Map<String, dynamic>> uploadActivitySummary({
    required Uint8List fileBytes,
    required String fileName,
    required String submissionId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'documentType': 'ActivitySummary',
      'submissionId': submissionId,
    });
    final response = await dio.post(
      '/documents/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Poll extraction status for a document.
  /// Returns 'extracted' or 'processing'.
  Future<String> getDocumentExtractionStatus(String documentId) async {
    try {
      final response = await dio.get('/documents/$documentId/extraction-status');
      final data = response.data as Map<String, dynamic>;
      return data['status'] as String? ?? 'processing';
    } catch (_) {
      return 'processing';
    }
  }
}

/// Placeholder for Guid type (just a String alias in Dart).
typedef Guid = String;
