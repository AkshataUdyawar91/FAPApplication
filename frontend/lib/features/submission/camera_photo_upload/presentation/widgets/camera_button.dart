import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A button that triggers camera capture for photo upload.
///
/// Displays a camera icon with a "Take Photo" label. Disabled when the
/// device does not support camera access. Meets WCAG AA touch target
/// (minimum 48×48 logical pixels) and contrast requirements.
class CameraButton extends StatelessWidget {
  /// Callback when the button is clicked.
  final VoidCallback? onPressed;

  /// Whether the camera is unavailable on this device.
  final bool isDisabled;

  /// Reason the camera is disabled (shown as tooltip).
  final String? disabledReason;

  /// Whether the camera is currently initializing.
  final bool isLoading;

  const CameraButton({
    super.key,
    this.onPressed,
    this.isDisabled = false,
    this.disabledReason,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = isDisabled || isLoading;

    return Tooltip(
      message: isDisabled
          ? (disabledReason ?? 'Camera not available')
          : 'Take a photo with your camera',
      child: Semantics(
        label: 'Take a photo with your device camera',
        button: true,
        enabled: !effectiveDisabled,
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: effectiveDisabled ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.camera_alt, size: 16),
            label: Text(
              isLoading ? 'Opening Camera...' : 'Take Photo',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
