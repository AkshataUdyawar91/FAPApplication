import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A dialog that opens the laptop/device webcam using the browser's
/// getUserMedia API and lets the user capture a photo.
///
/// Works on desktop browsers (Chrome, Firefox, Safari, Edge) and
/// mobile web views. Uses dart:html for direct browser API access
/// instead of image_picker, which only opens a file picker on desktop.
class WebCameraDialog extends StatefulWidget {
  const WebCameraDialog({super.key});

  @override
  State<WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<WebCameraDialog> {
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  String? _viewType;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  /// Initializes the camera by requesting getUserMedia access.
  Future<void> _initCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        },
        'audio': false,
      });

      if (!mounted) {
        _stopStream(stream);
        return;
      }

      _mediaStream = stream;

      final videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..srcObject = stream
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '8px';

      _videoElement = videoElement;

      final viewType = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';
      _viewType = viewType;

      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => videoElement,
      );

      await videoElement.play();

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } on html.DomException catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          if (e.name == 'NotAllowedError') {
            _errorMessage =
                'Camera access was denied. Please allow camera access in your browser settings.';
          } else if (e.name == 'NotFoundError') {
            _errorMessage =
                'No camera found on this device. Please connect a camera and try again.';
          } else {
            _errorMessage = 'Failed to access camera: ${e.message}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to access camera. Please try again.';
        });
      }
    }
  }

  /// Captures the current video frame as a JPEG image.
  Future<void> _capturePhoto() async {
    if (_videoElement == null || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final video = _videoElement!;
      final width = video.videoWidth;
      final height = video.videoHeight;

      if (width == 0 || height == 0) {
        setState(() {
          _isCapturing = false;
          _errorMessage = 'Camera not ready yet. Please wait a moment.';
        });
        return;
      }

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(video, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      final byteString = dataUrl.split(',').last;
      final bytes = _base64ToBytes(byteString);

      _stopCamera();

      if (mounted) {
        Navigator.of(context).pop({
          'imageData': bytes,
          'width': width,
          'height': height,
          'mimeType': 'image/jpeg',
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = 'Failed to capture photo. Please try again.';
        });
      }
    }
  }

  /// Converts a base64 string to Uint8List.
  Uint8List _base64ToBytes(String base64) {
    final binaryString = html.window.atob(base64);
    final bytes = Uint8List(binaryString.length);
    for (var i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.codeUnitAt(i);
    }
    return bytes;
  }

  /// Stops all tracks on the active media stream.
  void _stopCamera() {
    if (_mediaStream != null) {
      _stopStream(_mediaStream!);
      _mediaStream = null;
    }
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    _videoElement = null;
  }

  /// Stops all tracks on a given media stream.
  void _stopStream(html.MediaStream stream) {
    for (final track in stream.getTracks()) {
      track.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Flexible(child: _buildBody()),
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.camera_alt, color: AppColors.primary),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Camera',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () {
            _stopCamera();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close),
          tooltip: 'Close camera',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting camera...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.rejectedText),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.rejectedText),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isInitializing = true;
                  _errorMessage = null;
                });
                _initCamera();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_viewType == null) {
      return const Center(child: Text('Camera not available'));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: 360,
        child: HtmlElementView(viewType: _viewType!),
      ),
    );
  }

  Widget _buildActions() {
    if (_isInitializing || _errorMessage != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              _stopCamera();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            _stopCamera();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isCapturing ? null : _capturePhoto,
          icon: _isCapturing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.camera, size: 20),
          label: Text(_isCapturing ? 'Capturing...' : 'Capture Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
