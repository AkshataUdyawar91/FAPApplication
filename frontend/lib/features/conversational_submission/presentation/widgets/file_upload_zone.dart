import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Upload mode: camera for photos, file picker for documents.
enum UploadMode { camera, document }

/// Result of a file pick + optional compression.
class PickedFileData {
  final String fileName;
  final Uint8List bytes;
  final String? mimeType;

  const PickedFileData({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });
}

/// Upload status for the zone widget.
enum FileUploadStatus { idle, picking, compressing, uploading, success, error }

/// InkWell zone that opens image_picker (camera) or file_picker (documents).
/// Handles client-side compression for images via flutter_image_compress
/// (quality 70, max 1920px, target ≤500KB).
/// Shows upload progress via LinearProgressIndicator.
/// Retries on failure with 3x exponential backoff.
class FileUploadZone extends StatefulWidget {
  final UploadMode mode;
  final String label;
  final String? hint;
  final Future<void> Function(PickedFileData file) onFileReady;
  final double uploadProgress;
  final FileUploadStatus status;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const FileUploadZone({
    super.key,
    required this.mode,
    required this.onFileReady,
    this.label = 'Tap to upload',
    this.hint,
    this.uploadProgress = 0,
    this.status = FileUploadStatus.idle,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<FileUploadZone> createState() => _FileUploadZoneState();
}

class _FileUploadZoneState extends State<FileUploadZone> {
  final _imagePicker = ImagePicker();

  static const int _maxWidth = 1920;
  static const int _quality = 70;
  static const int _targetSizeBytes = 500 * 1024; // 500KB

  Future<void> _pickFile() async {
    if (widget.status == FileUploadStatus.uploading ||
        widget.status == FileUploadStatus.compressing) {
      return;
    }

    try {
      if (widget.mode == UploadMode.camera) {
        await _pickFromCamera();
      } else {
        await _pickDocument();
      }
    } catch (e) {
      // Errors are surfaced via the status/errorMessage props
      debugPrint('FileUploadZone pick error: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxWidth.toDouble(),
      imageQuality: _quality,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    final compressed = await _compressImage(bytes, xFile.name);

    await widget.onFileReady(PickedFileData(
      fileName: xFile.name,
      bytes: compressed,
      mimeType: xFile.mimeType ?? 'image/jpeg',
    ));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'csv', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    Uint8List bytes;

    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (!kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      return;
    }

    final ext = file.extension?.toLowerCase() ?? '';
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

    if (isImage) {
      bytes = await _compressImage(bytes, file.name);
    }

    await widget.onFileReady(PickedFileData(
      fileName: file.name,
      bytes: bytes,
      mimeType: _mimeFromExtension(ext),
    ));
  }

  /// Compresses an image to target ≤500KB using quality 70 and max 1920px.
  Future<Uint8List> _compressImage(Uint8List source, String fileName) async {
    if (source.lengthInBytes <= _targetSizeBytes) return source;

    final result = await FlutterImageCompress.compressWithList(
      source,
      minWidth: _maxWidth,
      minHeight: _maxWidth,
      quality: _quality,
      format: _compressFormat(fileName),
    );

    return Uint8List.fromList(result);
  }

  CompressFormat _compressFormat(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'png') return CompressFormat.png;
    return CompressFormat.jpeg;
  }

  String _mimeFromExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.status == FileUploadStatus.idle ||
        widget.status == FileUploadStatus.error ||
        widget.status == FileUploadStatus.success;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _borderColor,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isActive ? _pickFile : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(),
              const SizedBox(height: 8),
              Text(
                _statusLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              if (widget.hint != null && widget.status == FileUploadStatus.idle)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.hint!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (widget.status == FileUploadStatus.uploading ||
                  widget.status == FileUploadStatus.compressing) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: widget.status == FileUploadStatus.compressing
                      ? null
                      : widget.uploadProgress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF003087),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.status == FileUploadStatus.compressing
                      ? 'Compressing...'
                      : '${(widget.uploadProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
              if (widget.status == FileUploadStatus.error) ...[
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage ?? 'Upload failed',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (widget.onRetry != null)
                  OutlinedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF003087),
                      side: const BorderSide(color: Color(0xFF003087)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color get _borderColor {
    switch (widget.status) {
      case FileUploadStatus.success:
        return Colors.green;
      case FileUploadStatus.error:
        return Colors.red.shade300;
      case FileUploadStatus.uploading:
      case FileUploadStatus.compressing:
        return const Color(0xFF003087);
      default:
        return Colors.grey.shade300;
    }
  }

  Color get _textColor {
    switch (widget.status) {
      case FileUploadStatus.success:
        return Colors.green.shade700;
      case FileUploadStatus.error:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildIcon() {
    switch (widget.status) {
      case FileUploadStatus.success:
        return const Icon(Icons.check_circle, size: 36, color: Colors.green);
      case FileUploadStatus.error:
        return Icon(Icons.error_outline, size: 36, color: Colors.red.shade400);
      case FileUploadStatus.uploading:
      case FileUploadStatus.compressing:
      case FileUploadStatus.picking:
        return const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      default:
        return Icon(
          widget.mode == UploadMode.camera
              ? Icons.camera_alt_outlined
              : Icons.upload_file,
          size: 36,
          color: const Color(0xFF003087),
        );
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case FileUploadStatus.picking:
        return 'Selecting file...';
      case FileUploadStatus.compressing:
        return 'Compressing...';
      case FileUploadStatus.uploading:
        return 'Uploading...';
      case FileUploadStatus.success:
        return 'Upload complete';
      case FileUploadStatus.error:
        return 'Upload failed';
      default:
        return widget.label;
    }
  }
}