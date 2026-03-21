import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Opens the device camera on web using getUserMedia and returns a captured photo
/// as a [PlatformFile], or null if cancelled.
Future<PlatformFile?> capturePhotoOnWeb(BuildContext context) async {
  return showDialog<PlatformFile?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WebCameraDialog(),
  );
}

class _WebCameraDialog extends StatefulWidget {
  const _WebCameraDialog();

  @override
  State<_WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<_WebCameraDialog> {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;
  bool _isReady = false;
  bool _hasError = false;
  String _errorMessage = '';
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'webcam-${DateTime.now().millisecondsSinceEpoch}';
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '8px';

      // Register the view factory
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement!,
      );

      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment', 'width': 1280, 'height': 720},
        'audio': false,
      });

      _videoElement!.srcObject = _stream;
      await _videoElement!.play();

      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Camera access denied or not available.\n$e';
        });
      }
    }
  }

  Future<void> _captureSnapshot() async {
    if (_videoElement == null) return;

    final canvas = html.CanvasElement(
      width: _videoElement!.videoWidth,
      height: _videoElement!.videoHeight,
    );
    canvas.context2D.drawImage(_videoElement!, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64 = dataUrl.split(',').last;
    final bytes = base64Decode(base64);

    final fileName = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = PlatformFile(
      name: fileName,
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    );

    _stopCamera();
    if (mounted) Navigator.of(context).pop(file);
  }

  void _stopCamera() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Capture Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              )
            : !_isReady
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HtmlElementView(viewType: _viewId),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _stopCamera();
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancel'),
        ),
        if (_isReady && !_hasError)
          ElevatedButton.icon(
            onPressed: _captureSnapshot,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Capture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}
