import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';

/// Extraction status returned by the backend.
enum ExtractionStatus { pending, processing, completed, failed }

/// Overall upload lifecycle phase.
enum UploadPhase { idle, compressing, uploading, polling, complete, error }

/// State for a single file upload operation.
class FileUploadState extends Equatable {
  final UploadPhase phase;
  final double uploadProgress;
  final String? documentId;
  final ExtractionStatus? extractionStatus;
  final String? errorMessage;
  final int retryCount;

  const FileUploadState({
    this.phase = UploadPhase.idle,
    this.uploadProgress = 0,
    this.documentId,
    this.extractionStatus,
    this.errorMessage,
    this.retryCount = 0,
  });

  FileUploadState copyWith({
    UploadPhase? phase,
    double? uploadProgress,
    String? documentId,
    ExtractionStatus? extractionStatus,
    String? errorMessage,
    int? retryCount,
  }) {
    return FileUploadState(
      phase: phase ?? this.phase,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      documentId: documentId ?? this.documentId,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      errorMessage: errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        uploadProgress,
        documentId,
        extractionStatus,
        errorMessage,
        retryCount,
      ];
}

/// Riverpod StateNotifier handling:
/// - Client-side image compression (quality 70, max 1920px, target ≤500KB)
/// - Upload via Dio to POST /api/documents/upload
/// - Polls GET /api/documents/{id}/status every 3s
/// - Falls back to SignalR push after 60s polling timeout
/// - Retry on failure with 3x exponential backoff
class FileUploadNotifier extends StateNotifier<FileUploadState> {
  final Dio _dio;

  static const int _maxRetries = 3;
  static const int _pollIntervalMs = 3000;
  static const int _pollTimeoutMs = 60000;
  static const int _maxWidth = 1920;
  static const int _quality = 70;
  static const int _targetSizeBytes = 500 * 1024;

  Timer? _pollTimer;
  DateTime? _pollStartTime;

  /// Called when extraction completes (either via polling or SignalR push).
  void Function(String documentId)? onExtractionComplete;

  /// Called when polling times out and SignalR fallback should be used.
  void Function(String documentId)? onPollTimeout;

  FileUploadNotifier(this._dio) : super(const FileUploadState());

  /// Uploads a file with optional compression for images.
  /// [fileBytes] — raw file bytes.
  /// [fileName] — original file name.
  /// [submissionId] — the submission this document belongs to.
  /// [documentType] — e.g. "Invoice", "CostSummary", "Photo".
  Future<void> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String submissionId,
    required String documentType,
  }) async {
    state = const FileUploadState(phase: UploadPhase.compressing);

    try {
      // Compress if image
      Uint8List data = fileBytes;
      if (_isImage(fileName)) {
        data = await _compressImage(fileBytes, fileName);
      }

      state = state.copyWith(phase: UploadPhase.uploading, uploadProgress: 0);

      // Upload with retry
      final documentId = await _uploadWithRetry(
        data: data,
        fileName: fileName,
        submissionId: submissionId,
        documentType: documentType,
      );

      if (documentId == null) return; // error state already set

      state = state.copyWith(
        phase: UploadPhase.polling,
        documentId: documentId,
        extractionStatus: ExtractionStatus.pending,
      );

      _startPolling(documentId);
    } catch (e) {
      state = state.copyWith(
        phase: UploadPhase.error,
        errorMessage: 'Upload failed: $e',
      );
    }
  }

  /// Handles a SignalR push event for extraction completion.
  /// Call this from the SignalR notifier when ExtractionComplete is received.
  void handleExtractionComplete(String documentId) {
    if (state.documentId != documentId) return;
    _stopPolling();
    state = state.copyWith(
      phase: UploadPhase.complete,
      extractionStatus: ExtractionStatus.completed,
    );
    onExtractionComplete?.call(documentId);
  }

  /// Resets the notifier to idle state.
  void reset() {
    _stopPolling();
    state = const FileUploadState();
  }

  Future<Uint8List> _compressImage(Uint8List source, String fileName) async {
    if (source.lengthInBytes <= _targetSizeBytes) return source;

    final format = fileName.toLowerCase().endsWith('.png')
        ? CompressFormat.png
        : CompressFormat.jpeg;

    final result = await FlutterImageCompress.compressWithList(
      source,
      minWidth: _maxWidth,
      minHeight: _maxWidth,
      quality: _quality,
      format: format,
    );

    return Uint8List.fromList(result);
  }

  bool _isImage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  /// Uploads with up to 3 retries using exponential backoff (1s, 2s, 4s).
  Future<String?> _uploadWithRetry({
    required Uint8List data,
    required String fileName,
    required String submissionId,
    required String documentType,
  }) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        state = state.copyWith(retryCount: attempt);

        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(data, filename: fileName),
          'submissionId': submissionId,
          'documentType': documentType,
        });

        final response = await _dio.post(
          ApiConstants.uploadDocument,
          data: formData,
          onSendProgress: (sent, total) {
            if (total > 0) {
              state = state.copyWith(uploadProgress: sent / total);
            }
          },
        );

        final responseData = response.data as Map<String, dynamic>;
        return responseData['documentId'] as String? ??
            responseData['id'] as String?;
      } on DioException catch (e) {
        if (attempt == _maxRetries) {
          state = state.copyWith(
            phase: UploadPhase.error,
            errorMessage: 'Upload failed after ${_maxRetries + 1} attempts: '
                '${e.message ?? e.type.name}',
          );
          return null;
        }
        // Exponential backoff: 1s, 2s, 4s
        final delay = Duration(seconds: 1 << attempt);
        debugPrint('Upload attempt $attempt failed, retrying in $delay');
        await Future.delayed(delay);
      }
    }
    return null;
  }

  /// Polls GET /api/documents/{id}/status every 3s.
  /// After 60s, stops polling and signals SignalR fallback.
  void _startPolling(String documentId) {
    _pollStartTime = DateTime.now();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _pollStatus(documentId),
    );
  }

  Future<void> _pollStatus(String documentId) async {
    // Check timeout
    final elapsed =
        DateTime.now().difference(_pollStartTime!).inMilliseconds;
    if (elapsed >= _pollTimeoutMs) {
      _stopPolling();
      state = state.copyWith(
        extractionStatus: ExtractionStatus.processing,
      );
      onPollTimeout?.call(documentId);
      return;
    }

    try {
      final response = await _dio.get(
        ApiConstants.documentStatus(documentId),
      );
      final data = response.data as Map<String, dynamic>;
      final status = _parseExtractionStatus(data['status'] as String?);

      state = state.copyWith(extractionStatus: status);

      if (status == ExtractionStatus.completed ||
          status == ExtractionStatus.failed) {
        _stopPolling();
        state = state.copyWith(
          phase: status == ExtractionStatus.completed
              ? UploadPhase.complete
              : UploadPhase.error,
          errorMessage: status == ExtractionStatus.failed
              ? data['error'] as String? ?? 'Extraction failed'
              : null,
        );
        if (status == ExtractionStatus.completed) {
          onExtractionComplete?.call(documentId);
        }
      }
    } catch (e) {
      debugPrint('Poll status error: $e');
      // Don't stop polling on transient errors — let timeout handle it
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollStartTime = null;
  }

  ExtractionStatus _parseExtractionStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return ExtractionStatus.completed;
      case 'processing':
        return ExtractionStatus.processing;
      case 'failed':
        return ExtractionStatus.failed;
      default:
        return ExtractionStatus.pending;
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
