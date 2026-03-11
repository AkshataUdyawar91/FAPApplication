import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../domain/enums/camera_error_type.dart';
import '../../domain/enums/camera_permission_status.dart';
import '../../domain/enums/validation_type.dart';
import '../../domain/models/camera_error.dart';
import '../../domain/models/captured_photo.dart';
import '../../domain/models/processed_photo.dart';
import '../../domain/models/validation_result.dart';

/// Validation constants for captured photos.
class PhotoValidationConstants {
  PhotoValidationConstants._();

  /// Maximum file size in bytes (10MB).
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Minimum image width in pixels.
  static const int minWidth = 640;

  /// Minimum image height in pixels.
  static const int minHeight = 480;

  /// Maximum image width in pixels.
  static const int maxWidth = 4096;

  /// Maximum image height in pixels.
  static const int maxHeight = 4096;

  /// Allowed MIME types for captured photos.
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
  ];
}

/// Service responsible for camera access, photo capture, and validation.
///
/// Uses [ImagePicker] to provide cross-platform camera support on web,
/// mobile, and desktop. Handles permission management, photo capture,
/// validation, and resource cleanup.
class CameraService {
  final ImagePicker _imagePicker;

  /// The last picked image file, held for resource cleanup.
  XFile? _lastPickedFile;

  /// Tracks whether camera permission has been granted this session.
  bool _permissionGranted = false;

  /// Creates a [CameraService] with an optional [ImagePicker] instance.
  ///
  /// Accepts an [ImagePicker] for testability via dependency injection.
  CameraService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  /// Checks if the device supports camera access.
  ///
  /// On web, camera support depends on the browser supporting the
  /// MediaDevices API (getUserMedia). On native platforms, camera
  /// is generally available. Returns `false` if detection fails.
  Future<bool> isCameraSupported() async {
    try {
      // image_picker supports camera on web (via getUserMedia),
      // Android, and iOS. On web, the browser must support
      // MediaDevices API. We use supportsImageSource to check.
      return ImagePicker().supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  /// Requests camera permission from the user.
  ///
  /// On web, permissions are requested implicitly when the browser
  /// camera dialog opens via [ImagePicker.pickImage]. This method
  /// attempts a lightweight camera access to trigger the permission
  /// prompt. Returns the resulting [CameraPermissionStatus].
  Future<CameraPermissionStatus> requestCameraPermission() async {
    try {
      // On web, the permission prompt is shown by the browser when
      // we attempt to access the camera. We use pickImage which
      // triggers getUserMedia under the hood.
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: PhotoValidationConstants.maxWidth.toDouble(),
        maxHeight: PhotoValidationConstants.maxHeight.toDouble(),
      );

      if (file != null) {
        // Permission was granted and user captured a photo.
        _permissionGranted = true;
        _lastPickedFile = file;
        return CameraPermissionStatus.granted;
      }

      // User cancelled the camera dialog — permission state unclear.
      // Treat as not determined since they didn't deny, just cancelled.
      return CameraPermissionStatus.notDetermined;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('notallowed')) {
        return CameraPermissionStatus.denied;
      }
      if (errorMessage.contains('permanently') ||
          errorMessage.contains('forever')) {
        return CameraPermissionStatus.deniedForever;
      }
      return CameraPermissionStatus.denied;
    }
  }

  /// Returns the current camera permission status.
  ///
  /// On web, there is no direct API to query permission status without
  /// triggering a prompt. This returns the cached status from the
  /// current session. If permission was previously granted via
  /// [requestCameraPermission], returns [CameraPermissionStatus.granted].
  Future<CameraPermissionStatus> getCameraPermissionStatus() async {
    if (_permissionGranted) {
      return CameraPermissionStatus.granted;
    }
    return CameraPermissionStatus.notDetermined;
  }

  /// Captures a photo from the device camera.
  ///
  /// Opens the camera interface via [ImagePicker] and returns a
  /// [CapturedPhoto] with the image data. Throws a [CameraError]
  /// if capture fails.
  ///
  /// If a photo was already captured during [requestCameraPermission],
  /// returns that photo to avoid opening the camera twice.
  Future<CapturedPhoto> capturePhoto() async {
    try {
      XFile? file = _lastPickedFile;
      _lastPickedFile = null;

      // If no file from permission request, open camera fresh.
      file ??= await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: PhotoValidationConstants.maxWidth.toDouble(),
        maxHeight: PhotoValidationConstants.maxHeight.toDouble(),
      );

      if (file == null) {
        throw const CameraError(
          type: CameraErrorType.captureError,
          message: 'Photo capture was cancelled.',
        );
      }

      _permissionGranted = true;
      final imageData = await file.readAsBytes();
      final mimeType = _resolveMimeType(file.mimeType, file.name);
      final imageSize = await _getImageDimensions(imageData);

      return CapturedPhoto(
        imageData: imageData,
        mimeType: mimeType,
        capturedAt: DateTime.now(),
        width: imageSize.width,
        height: imageSize.height,
        fileSizeBytes: imageData.length,
      );
    } on CameraError {
      rethrow;
    } catch (e) {
      throw CameraError(
        type: CameraErrorType.captureError,
        message: 'Failed to capture photo. Please try again.',
        details: e.toString(),
      );
    }
  }

  /// Validates a captured photo against format, size, and dimension rules.
  ///
  /// Checks:
  /// - MIME type is JPEG or PNG
  /// - File size does not exceed 10MB
  /// - Dimensions are at least 640×480
  /// - Dimensions do not exceed 4096×4096
  ///
  /// Returns a [ValidationResult] with any errors found.
  Future<ValidationResult> validatePhoto(CapturedPhoto photo) async {
    final errors = <ValidationError>[];

    // Validate format by MIME type.
    if (!PhotoValidationConstants.allowedMimeTypes.contains(photo.mimeType)) {
      errors.add(const ValidationError(
        type: ValidationType.invalidFormat,
        message:
            'Photo format is not supported. Please use JPEG or PNG format.',
      ));
    }

    // Validate file size.
    if (photo.fileSizeBytes > PhotoValidationConstants.maxFileSizeBytes) {
      final sizeMb =
          (photo.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      errors.add(ValidationError(
        type: ValidationType.fileTooLarge,
        message: 'Photo is too large (${sizeMb}MB). Maximum size is 10MB.',
      ));
    }

    // Validate minimum dimensions.
    if (photo.width < PhotoValidationConstants.minWidth ||
        photo.height < PhotoValidationConstants.minHeight) {
      errors.add(ValidationError(
        type: ValidationType.imageTooSmall,
        message:
            'Photo resolution is too low (${photo.width}×${photo.height}). '
            'Minimum is ${PhotoValidationConstants.minWidth}×${PhotoValidationConstants.minHeight}.',
      ));
    }

    // Validate maximum dimensions.
    if (photo.width > PhotoValidationConstants.maxWidth ||
        photo.height > PhotoValidationConstants.maxHeight) {
      errors.add(ValidationError(
        type: ValidationType.imageTooLarge,
        message:
            'Photo resolution is too high (${photo.width}×${photo.height}). '
            'Maximum is ${PhotoValidationConstants.maxWidth}×${PhotoValidationConstants.maxHeight}.',
      ));
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Processes a captured photo for upload.
  ///
  /// Converts the [CapturedPhoto] to a [ProcessedPhoto]. The image_picker
  /// already handles format conversion and resizing via its `imageQuality`,
  /// `maxWidth`, and `maxHeight` parameters, so this primarily wraps the
  /// data into the upload-ready model.
  Future<ProcessedPhoto> processPhoto(CapturedPhoto photo) async {
    try {
      return ProcessedPhoto(
        imageData: Uint8List.fromList(photo.imageData),
        mimeType: photo.mimeType,
        width: photo.width,
        height: photo.height,
        fileSizeBytes: photo.fileSizeBytes,
        processedAt: DateTime.now(),
      );
    } catch (e) {
      throw CameraError(
        type: CameraErrorType.processingError,
        message: 'Failed to process photo. Please try again.',
        details: e.toString(),
      );
    }
  }

  /// Releases all camera resources and clears held references.
  ///
  /// On web, the browser manages MediaStream lifecycle through the
  /// image_picker dialog. This method clears any cached file references
  /// to free memory.
  Future<void> releaseCameraResources() async {
    _lastPickedFile = null;
  }

  /// Resolves the MIME type from the file metadata or name extension.
  ///
  /// Falls back to `image/jpeg` if the type cannot be determined.
  String _resolveMimeType(String? mimeType, String fileName) {
    if (mimeType != null && mimeType.isNotEmpty) {
      return mimeType;
    }

    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    // Default to JPEG as it's the most common camera output.
    return 'image/jpeg';
  }

  /// Extracts image dimensions from raw bytes by reading file headers.
  ///
  /// Supports JPEG and PNG formats. Returns a default size if the
  /// format cannot be parsed.
  Future<_ImageSize> _getImageDimensions(Uint8List data) async {
    try {
      // Try PNG: starts with 0x89 0x50 0x4E 0x47
      if (data.length > 24 &&
          data[0] == 0x89 &&
          data[1] == 0x50 &&
          data[2] == 0x4E &&
          data[3] == 0x47) {
        return _parsePngDimensions(data);
      }

      // Try JPEG: starts with 0xFF 0xD8
      if (data.length > 2 && data[0] == 0xFF && data[1] == 0xD8) {
        return _parseJpegDimensions(data);
      }
    } catch (_) {
      // Fall through to default.
    }

    // Default dimensions when parsing fails.
    return const _ImageSize(width: 0, height: 0);
  }

  /// Parses width and height from a PNG file's IHDR chunk.
  _ImageSize _parsePngDimensions(Uint8List data) {
    // PNG IHDR chunk: width at bytes 16-19, height at bytes 20-23 (big-endian).
    final width = (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19];
    final height = (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
    return _ImageSize(width: width, height: height);
  }

  /// Parses width and height from a JPEG file's SOF marker.
  _ImageSize _parseJpegDimensions(Uint8List data) {
    var offset = 2;
    while (offset < data.length - 1) {
      if (data[offset] != 0xFF) break;

      final marker = data[offset + 1];

      // SOF0 through SOF3 markers contain dimensions.
      if (marker >= 0xC0 && marker <= 0xC3) {
        if (offset + 9 < data.length) {
          final height = (data[offset + 5] << 8) | data[offset + 6];
          final width = (data[offset + 7] << 8) | data[offset + 8];
          return _ImageSize(width: width, height: height);
        }
      }

      // Skip to next marker.
      if (offset + 3 < data.length) {
        final segmentLength = (data[offset + 2] << 8) | data[offset + 3];
        offset += 2 + segmentLength;
      } else {
        break;
      }
    }

    return const _ImageSize(width: 0, height: 0);
  }
}

/// Internal value type for image dimensions.
class _ImageSize {
  final int width;
  final int height;

  const _ImageSize({required this.width, required this.height});
}
