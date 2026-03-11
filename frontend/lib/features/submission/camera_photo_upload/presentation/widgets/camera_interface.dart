import 'package:flutter/material.dart';

import '../../domain/models/camera_error.dart';
import '../../domain/models/captured_photo.dart';

/// Orchestrates the camera capture flow using [image_picker].
///
/// On Flutter Web, the browser handles the camera UI natively via
/// `getUserMedia`. This widget manages the flow: trigger capture →
/// return result or error. There is no custom camera preview since
/// the browser provides its own camera dialog.
///
/// Adapts to orientation changes automatically since the browser
/// dialog handles its own layout. Resources are released when the
/// dialog closes.
class CameraInterface extends StatelessWidget {
  /// Callback with the captured photo data.
  final ValueChanged<CapturedPhoto>? onCapture;

  /// Callback when the user cancels capture.
  final VoidCallback? onCancel;

  /// Callback when a camera error occurs.
  final ValueChanged<CameraError>? onError;

  const CameraInterface({
    super.key,
    this.onCapture,
    this.onCancel,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    // The browser's native camera dialog is used via image_picker.
    // This widget is a placeholder that can be used as a loading
    // indicator while the camera dialog is open.
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Camera is opening...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
