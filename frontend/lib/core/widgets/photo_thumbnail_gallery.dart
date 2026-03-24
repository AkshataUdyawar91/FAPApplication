import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Data model for a single photo thumbnail with validation status.
class PhotoThumbnailItem {
  final String documentId;
  final String fileName;
  final bool hasError;
  final bool isPending;

  const PhotoThumbnailItem({
    required this.documentId,
    required this.fileName,
    required this.hasError,
    required this.isPending,
  });
}

/// Responsive photo thumbnail gallery using Wrap.
/// Shows small 80x80 thumbnails with thick colored borders:
/// - Red (3px) for validation errors
/// - Green (3px) for passed validation
/// - Grey (3px) for pending (no validation data)
class PhotoThumbnailGallery extends StatefulWidget {
  final List<PhotoThumbnailItem> photos;
  final String token;
  final void Function(String documentId, String fileName)? onPhotoTap;

  const PhotoThumbnailGallery({
    super.key,
    required this.photos,
    required this.token,
    this.onPhotoTap,
  });

  @override
  State<PhotoThumbnailGallery> createState() => _PhotoThumbnailGalleryState();
}

class _PhotoThumbnailGalleryState extends State<PhotoThumbnailGallery> {
  final Map<String, Uint8List> _imageCache = {};
  final Set<String> _loadingIds = {};
  final Set<String> _failedIds = {};

  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));

  @override
  void initState() {
    super.initState();
    _loadImagesInBatches();
  }

  /// Loads images in batches of 10 to avoid flooding the API.
  Future<void> _loadImagesInBatches() async {
    // Deduplicate by documentId (test multiplier reuses same IDs)
    final uniqueIds = <String>{};
    final toLoad = <PhotoThumbnailItem>[];
    for (final photo in widget.photos) {
      if (uniqueIds.add(photo.documentId) &&
          !_imageCache.containsKey(photo.documentId) &&
          !_loadingIds.contains(photo.documentId)) {
        toLoad.add(photo);
      }
    }

    const batchSize = 10;
    for (int i = 0; i < toLoad.length; i += batchSize) {
      if (!mounted) return;
      final batch = toLoad.skip(i).take(batchSize);
      await Future.wait(batch.map((p) => _loadImage(p.documentId)));
    }
  }

  Future<void> _loadImage(String documentId) async {
    if (_imageCache.containsKey(documentId) ||
        _loadingIds.contains(documentId)) return;

    _loadingIds.add(documentId);

    try {
      final response = await _dio.get(
        '/documents/$documentId/download',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );
      if (response.statusCode == 200 && mounted) {
        final base64Content =
            response.data['base64Content']?.toString() ?? '';
        if (base64Content.isNotEmpty) {
          final bytes = base64.decode(base64Content);
          setState(() {
            _imageCache[documentId] = Uint8List.fromList(bytes);
            _loadingIds.remove(documentId);
          });
          return;
        }
      }
    } catch (_) {
      // Mark as failed
    }

    if (mounted) {
      setState(() {
        _failedIds.add(documentId);
        _loadingIds.remove(documentId);
      });
    }
  }

  Color _borderColor(PhotoThumbnailItem photo) {
    if (photo.hasError) return const Color(0xFFDC2626);
    if (photo.isPending) return const Color(0xFF9CA3AF);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    final errorCount =
        widget.photos.where((p) => p.hasError).length;
    final passedCount =
        widget.photos.where((p) => !p.hasError && !p.isPending).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.photo_library,
                    color: Color(0xFF003087), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Team Photos (${widget.photos.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                if (errorCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$errorCount failed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (passedCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$passedCount passed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Photo grid using Wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.photos.map((photo) {
                return _buildThumbnail(photo);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(PhotoThumbnailItem photo) {
    final bytes = _imageCache[photo.documentId];
    final isLoading = _loadingIds.contains(photo.documentId);
    final isFailed = _failedIds.contains(photo.documentId);

    return GestureDetector(
      onTap: () => widget.onPhotoTap?.call(photo.documentId, photo.fileName),
      child: Tooltip(
        message: photo.fileName,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _borderColor(photo),
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: 74,
                    height: 74,
                    errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image),
                  )
                : isLoading
                    ? _placeholder(Icons.hourglass_empty)
                    : isFailed
                        ? _placeholder(Icons.broken_image)
                        : _placeholder(Icons.image),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(icon, size: 24, color: const Color(0xFF9CA3AF)),
      ),
    );
  }
}
