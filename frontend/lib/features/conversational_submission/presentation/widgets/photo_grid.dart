import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Validation status for a single photo.
enum PhotoValidationStatus { pending, passed, failed }

/// Data for a single photo in the grid.
class PhotoGridItem {
  final String id;
  final String? thumbnailUrl;
  final Uint8List? thumbnailBytes;
  final PhotoValidationStatus validationStatus;
  final String? validationMessage;

  const PhotoGridItem({
    required this.id,
    this.thumbnailUrl,
    this.thumbnailBytes,
    this.validationStatus = PhotoValidationStatus.pending,
    this.validationMessage,
  });
}

/// GridView.builder thumbnail grid with per-photo AI validation status icons
/// and replace/add actions. Responsive crossAxisCount based on screen width.
class PhotoGrid extends StatelessWidget {
  final List<PhotoGridItem> photos;
  final void Function(int index) onReplace;
  final VoidCallback? onAddMore;
  final int minPhotos;
  final int maxPhotos;

  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onReplace,
    this.onAddMore,
    this.minPhotos = 3,
    this.maxPhotos = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo count indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.photo_library, size: 16, color: Color(0xFF003087)),
              const SizedBox(width: 6),
              Text(
                '${photos.length} / $maxPhotos photos (min $minPhotos)',
                style: TextStyle(
                  fontSize: 13,
                  color: photos.length < minPhotos
                      ? Colors.red.shade700
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _crossAxisCount(constraints.maxWidth);
            final itemCount =
                photos.length < maxPhotos && onAddMore != null
                    ? photos.length + 1
                    : photos.length;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return _AddPhotoTile(onTap: onAddMore!);
                }
                return _PhotoTile(
                  photo: photos[index],
                  onReplace: () => onReplace(index),
                );
              },
            );
          },
        ),
      ],
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1024) return 5; // desktop
    if (width >= 600) return 4;  // tablet
    return 3;                     // mobile
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoGridItem photo;
  final VoidCallback onReplace;

  const _PhotoTile({required this.photo, required this.onReplace});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildThumbnail(),
        ),
        // Validation status badge
        Positioned(
          top: 4,
          right: 4,
          child: _buildStatusBadge(),
        ),
        // Replace action
        Positioned(
          bottom: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onReplace,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail() {
    if (photo.thumbnailBytes != null) {
      return Image.memory(
        photo.thumbnailBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    if (photo.thumbnailUrl != null) {
      return Image.network(
        photo.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }
    return _placeholderImage();
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.image, size: 32, color: Colors.grey.shade400),
    );
  }

  Widget _buildStatusBadge() {
    switch (photo.validationStatus) {
      case PhotoValidationStatus.passed:
        return const _Badge(icon: Icons.check_circle, color: Colors.green);
      case PhotoValidationStatus.failed:
        return const _Badge(icon: Icons.cancel, color: Colors.red);
      case PhotoValidationStatus.pending:
        return _Badge(
          icon: Icons.hourglass_empty,
          color: Colors.grey.shade500,
        );
    }
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF003087),
            style: BorderStyle.solid,
            width: 1.5,
          ),
          color: const Color(0xFF003087).withValues(alpha: 0.05),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 28, color: Color(0xFF003087)),
            SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF003087),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
