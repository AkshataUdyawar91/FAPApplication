import 'dart:typed_data';

import 'package:bajaj_document_processing/features/submission/camera_photo_upload/data/services/camera_service.dart';
import 'package:bajaj_document_processing/features/submission/camera_photo_upload/domain/enums/camera_error_type.dart';
import 'package:bajaj_document_processing/features/submission/camera_photo_upload/domain/enums/camera_permission_status.dart';
import 'package:bajaj_document_processing/features/submission/camera_photo_upload/domain/enums/validation_type.dart';
import 'package:bajaj_document_processing/features/submission/camera_photo_upload/domain/models/camera_error.dart';
import 'package:bajaj_document_processing/features/submission/camera_photo_upload/domain/models/captured_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------------------
// Manual mock for ImagePicker — avoids build_runner / mockito codegen.
// ---------------------------------------------------------------------------

/// A configurable fake [ImagePicker] for unit testing.
class FakeImagePicker extends ImagePicker {
  XFile? fileToReturn;
  Exception? exceptionToThrow;
  int pickImageCallCount = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    pickImageCallCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return fileToReturn;
  }
}

// ---------------------------------------------------------------------------
// Helpers to build minimal valid image byte buffers.
// ---------------------------------------------------------------------------

/// Builds a minimal PNG byte buffer with the given dimensions.
Uint8List buildPngBytes({int width = 800, int height = 600}) {
  final bytes = Uint8List(33);

  // PNG signature.
  bytes[0] = 0x89;
  bytes[1] = 0x50;
  bytes[2] = 0x4E;
  bytes[3] = 0x47;
  bytes[4] = 0x0D;
  bytes[5] = 0x0A;
  bytes[6] = 0x1A;
  bytes[7] = 0x0A;

  // IHDR chunk length.
  bytes[11] = 0x0D;
  bytes[12] = 0x49;
  bytes[13] = 0x48;
  bytes[14] = 0x44;
  bytes[15] = 0x52;

  // Width (big-endian).
  bytes[16] = (width >> 24) & 0xFF;
  bytes[17] = (width >> 16) & 0xFF;
  bytes[18] = (width >> 8) & 0xFF;
  bytes[19] = width & 0xFF;

  // Height (big-endian).
  bytes[20] = (height >> 24) & 0xFF;
  bytes[21] = (height >> 16) & 0xFF;
  bytes[22] = (height >> 8) & 0xFF;
  bytes[23] = height & 0xFF;

  return bytes;
}

/// Builds a minimal JPEG byte buffer with the given dimensions.
Uint8List buildJpegBytes({int width = 800, int height = 600}) {
  final bytes = Uint8List(20);

  // SOI marker.
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;

  // SOF0 marker.
  bytes[2] = 0xFF;
  bytes[3] = 0xC0;

  // Segment length.
  bytes[4] = 0x00;
  bytes[5] = 0x0B;

  // Precision.
  bytes[6] = 0x08;

  // Height (big-endian).
  bytes[7] = (height >> 8) & 0xFF;
  bytes[8] = height & 0xFF;

  // Width (big-endian).
  bytes[9] = (width >> 8) & 0xFF;
  bytes[10] = width & 0xFF;

  return bytes;
}

/// A fake [XFile] backed by in-memory bytes for testing.
class FakeXFile extends XFile {
  final Uint8List _bytes;
  final String? _fakeMimeType;

  FakeXFile(
    this._bytes, {
    String name = 'photo.jpg',
    String? mimeType,
  })  : _fakeMimeType = mimeType,
        super(name, name: name, mimeType: mimeType);

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  String? get mimeType => _fakeMimeType;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeImagePicker fakeImagePicker;
  late CameraService cameraService;

  setUp(() {
    fakeImagePicker = FakeImagePicker();
    cameraService = CameraService(imagePicker: fakeImagePicker);
  });

  group('CameraService', () {
    group('requestCameraPermission', () {
      test('returns granted when user captures a photo', () async {
        fakeImagePicker.fileToReturn = FakeXFile(
          buildJpegBytes(),
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        );

        final status = await cameraService.requestCameraPermission();

        expect(status, CameraPermissionStatus.granted);
      });

      test('returns notDetermined when user cancels camera dialog', () async {
        fakeImagePicker.fileToReturn = null;

        final status = await cameraService.requestCameraPermission();

        expect(status, CameraPermissionStatus.notDetermined);
      });

      test('returns denied when permission error occurs', () async {
        fakeImagePicker.exceptionToThrow =
            Exception('Permission denied by user');

        final status = await cameraService.requestCameraPermission();

        expect(status, CameraPermissionStatus.denied);
      });

      test('returns denied on unknown error', () async {
        fakeImagePicker.exceptionToThrow =
            Exception('Some unknown error');

        final status = await cameraService.requestCameraPermission();

        expect(status, CameraPermissionStatus.denied);
      });
    });

    group('getCameraPermissionStatus', () {
      test('returns notDetermined initially', () async {
        final status = await cameraService.getCameraPermissionStatus();

        expect(status, CameraPermissionStatus.notDetermined);
      });

      test('returns granted after successful permission request', () async {
        fakeImagePicker.fileToReturn = FakeXFile(
          buildJpegBytes(),
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        );

        await cameraService.requestCameraPermission();
        final status = await cameraService.getCameraPermissionStatus();

        expect(status, CameraPermissionStatus.granted);
      });
    });

    group('capturePhoto', () {
      test('returns CapturedPhoto with correct data for JPEG', () async {
        final jpegBytes = buildJpegBytes(width: 1024, height: 768);
        fakeImagePicker.fileToReturn = FakeXFile(
          jpegBytes,
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        );

        final photo = await cameraService.capturePhoto();

        expect(photo.mimeType, 'image/jpeg');
        expect(photo.width, 1024);
        expect(photo.height, 768);
        expect(photo.fileSizeBytes, jpegBytes.length);
        expect(photo.imageData, jpegBytes);
      });

      test('returns CapturedPhoto with correct data for PNG', () async {
        final pngBytes = buildPngBytes(width: 1920, height: 1080);
        fakeImagePicker.fileToReturn = FakeXFile(
          pngBytes,
          name: 'photo.png',
          mimeType: 'image/png',
        );

        final photo = await cameraService.capturePhoto();

        expect(photo.mimeType, 'image/png');
        expect(photo.width, 1920);
        expect(photo.height, 1080);
      });

      test('throws CameraError when user cancels capture', () async {
        fakeImagePicker.fileToReturn = null;

        expect(
          () => cameraService.capturePhoto(),
          throwsA(
            isA<CameraError>().having(
              (e) => e.type,
              'type',
              CameraErrorType.captureError,
            ),
          ),
        );
      });

      test('throws CameraError on unexpected exception', () async {
        fakeImagePicker.exceptionToThrow = Exception('Hardware failure');

        expect(
          () => cameraService.capturePhoto(),
          throwsA(
            isA<CameraError>().having(
              (e) => e.type,
              'type',
              CameraErrorType.captureError,
            ),
          ),
        );
      });

      test('uses cached file from requestCameraPermission', () async {
        final jpegBytes = buildJpegBytes(width: 640, height: 480);
        fakeImagePicker.fileToReturn = FakeXFile(
          jpegBytes,
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        );

        // First call caches the file.
        await cameraService.requestCameraPermission();
        expect(fakeImagePicker.pickImageCallCount, 1);

        // capturePhoto should use cached file without calling pickImage again.
        final photo = await cameraService.capturePhoto();

        expect(photo.width, 640);
        expect(photo.height, 480);
        expect(fakeImagePicker.pickImageCallCount, 1);
      });

      test('resolves MIME type from file name when mimeType is null',
          () async {
        final pngBytes = buildPngBytes(width: 800, height: 600);
        fakeImagePicker.fileToReturn = FakeXFile(
          pngBytes,
          name: 'photo.png',
          mimeType: null,
        );

        final photo = await cameraService.capturePhoto();

        expect(photo.mimeType, 'image/png');
      });

      test('defaults MIME type to image/jpeg for unknown extension',
          () async {
        final pngBytes = buildPngBytes(width: 800, height: 600);
        fakeImagePicker.fileToReturn = FakeXFile(
          pngBytes,
          name: 'photo.webp',
          mimeType: null,
        );

        final photo = await cameraService.capturePhoto();

        expect(photo.mimeType, 'image/jpeg');
      });
    });

    group('validatePhoto', () {
      CapturedPhoto makePhoto({
        String mimeType = 'image/jpeg',
        int fileSizeBytes = 1024,
        int width = 800,
        int height = 600,
      }) {
        return CapturedPhoto(
          imageData: Uint8List(fileSizeBytes),
          mimeType: mimeType,
          capturedAt: DateTime.now(),
          width: width,
          height: height,
          fileSizeBytes: fileSizeBytes,
        );
      }

      test('valid JPEG photo passes validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(mimeType: 'image/jpeg'),
        );

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('valid PNG photo passes validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(mimeType: 'image/png'),
        );

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('invalid format fails validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(mimeType: 'image/gif'),
        );

        expect(result.isValid, isFalse);
        expect(result.errors.length, 1);
        expect(result.errors.first.type, ValidationType.invalidFormat);
      });

      test('file too large fails validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(
            fileSizeBytes: PhotoValidationConstants.maxFileSizeBytes + 1,
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.type == ValidationType.fileTooLarge),
          isTrue,
        );
      });

      test('image too small fails validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(width: 320, height: 240),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.type == ValidationType.imageTooSmall),
          isTrue,
        );
      });

      test('image too large fails validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(width: 5000, height: 5000),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.type == ValidationType.imageTooLarge),
          isTrue,
        );
      });

      test('multiple validation errors returned together', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(
            mimeType: 'image/bmp',
            fileSizeBytes: PhotoValidationConstants.maxFileSizeBytes + 1,
            width: 100,
            height: 100,
          ),
        );

        expect(result.isValid, isFalse);
        expect(result.errors.length, 3);
      });

      test('boundary min dimensions pass validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(
            width: PhotoValidationConstants.minWidth,
            height: PhotoValidationConstants.minHeight,
          ),
        );

        expect(result.isValid, isTrue);
      });

      test('boundary max dimensions pass validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(
            width: PhotoValidationConstants.maxWidth,
            height: PhotoValidationConstants.maxHeight,
          ),
        );

        expect(result.isValid, isTrue);
      });

      test('exact max file size passes validation', () async {
        final result = await cameraService.validatePhoto(
          makePhoto(
            fileSizeBytes: PhotoValidationConstants.maxFileSizeBytes,
          ),
        );

        expect(result.isValid, isTrue);
      });
    });

    group('processPhoto', () {
      test('returns ProcessedPhoto with matching data', () async {
        final imageData = buildJpegBytes(width: 800, height: 600);
        final photo = CapturedPhoto(
          imageData: imageData,
          mimeType: 'image/jpeg',
          capturedAt: DateTime.now(),
          width: 800,
          height: 600,
          fileSizeBytes: imageData.length,
        );

        final processed = await cameraService.processPhoto(photo);

        expect(processed.mimeType, photo.mimeType);
        expect(processed.width, photo.width);
        expect(processed.height, photo.height);
        expect(processed.fileSizeBytes, photo.fileSizeBytes);
        expect(processed.imageData, photo.imageData);
      });

      test('processedAt is set to current time', () async {
        final before = DateTime.now();
        final imageData = buildPngBytes();
        final photo = CapturedPhoto(
          imageData: imageData,
          mimeType: 'image/png',
          capturedAt: DateTime.now(),
          width: 800,
          height: 600,
          fileSizeBytes: imageData.length,
        );

        final processed = await cameraService.processPhoto(photo);
        final after = DateTime.now();

        expect(
          processed.processedAt.isAfter(before) ||
              processed.processedAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          processed.processedAt.isBefore(after) ||
              processed.processedAt.isAtSameMomentAs(after),
          isTrue,
        );
      });
    });

    group('releaseCameraResources', () {
      test('clears cached file so next capture opens camera fresh', () async {
        final jpegBytes = buildJpegBytes();
        fakeImagePicker.fileToReturn = FakeXFile(
          jpegBytes,
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        );

        // Cache a file via permission request.
        await cameraService.requestCameraPermission();
        expect(fakeImagePicker.pickImageCallCount, 1);

        // Release resources.
        await cameraService.releaseCameraResources();

        // Next capturePhoto should call pickImage again.
        await cameraService.capturePhoto();
        expect(fakeImagePicker.pickImageCallCount, 2);
      });
    });
  });
}
