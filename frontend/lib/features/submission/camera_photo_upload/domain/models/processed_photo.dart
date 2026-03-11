import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Represents a photo that has been processed and is ready for upload.
class ProcessedPhoto extends Equatable {
  /// Processed image bytes.
  final Uint8List imageData;

  /// Final MIME type (JPEG or PNG).
  final String mimeType;

  /// Final image width in pixels.
  final int width;

  /// Final image height in pixels.
  final int height;

  /// Final file size in bytes.
  final int fileSizeBytes;

  /// Timestamp when processing completed.
  final DateTime processedAt;

  const ProcessedPhoto({
    required this.imageData,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required this.processedAt,
  });

  @override
  List<Object?> get props => [
        imageData,
        mimeType,
        width,
        height,
        fileSizeBytes,
        processedAt,
      ];
}
