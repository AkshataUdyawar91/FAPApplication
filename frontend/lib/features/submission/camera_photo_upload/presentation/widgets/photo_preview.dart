import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Displays a preview of a captured photo with confirm, retake, and
/// discard actions.
///
/// Shows a loading indicator while the photo is being processed or
/// validated. Displays validation errors if the photo fails checks.
class PhotoPreview extends StatelessWidget {
  /// The captured image data to preview.
  final Uint8List imageData;

  /// Callback when the user confirms the photo.
  final VoidCallback? onConfirm;

  /// Callback when the user wants to retake the photo.
  final VoidCallback? onRetake;

  /// Callback when the user discards the photo.
  final VoidCallback? onDiscard;

  /// Whether the photo is being processed or validated.
  final bool isProcessing;

  /// Optional error message to display.
  final String? errorMessage;

  const PhotoPreview({
    super.key,
    required this.imageData,
    this.onConfirm,
    this.onRetake,
    this.onDiscard,
    this.isProcessing = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildImagePreview(),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                _buildErrorBanner(),
              ],
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the dialog header with title and close button.
  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.photo_camera, color: AppColors.primary),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Photo Preview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: onDiscard,
          icon: const Icon(Icons.close),
          tooltip: 'Discard photo',
        ),
      ],
    );
  }

  /// Builds the image preview area.
  Widget _buildImagePreview() {
    return Flexible(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          label: 'Captured photo preview',
          image: true,
          child: Image.memory(
            imageData,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// Builds the error banner shown when validation fails.
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.rejectedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rejectedBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.rejectedText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.rejectedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the action buttons (discard, retake, confirm).
  Widget _buildActions() {
    if (isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onDiscard,
          child: const Text('Discard'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retake'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Use Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
