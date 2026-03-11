import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Represents a photo captured directly from the device camera.
class CapturedPhoto extends Equatable {
  /// Raw image bytes.
  final Uint8List imageData;

  /// MIME type of the image (e.g., "image/jpeg").
  final String mimeType;

  /// Timestamp when the photo was captured.
  final DateTime capturedAt;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// File size in bytes.
  final int fileSizeBytes;

  const CapturedPhoto({
    required this.imageData,
    required this.mimeType,
    required this.capturedAt,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
  });

  @override
  List<Object?> get props => [
        imageData,
        mimeType,
        capturedAt,
        width,
        height,
        fileSizeBytes,
      ];
}
