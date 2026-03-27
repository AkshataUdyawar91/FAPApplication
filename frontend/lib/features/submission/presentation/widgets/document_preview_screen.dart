import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Document preview data model
class DocumentPreviewData {
  final String filename;
  final String imageUrl;
  final bool isPassed;
  final String? failureReason;
  final String? date;

  DocumentPreviewData({
    required this.filename,
    required this.imageUrl,
    required this.isPassed,
    this.failureReason,
    this.date,
  });
}

/// Document Preview Screen Widget
/// Two-section layout: image preview (left) + details panel (right)
class DocumentPreviewScreen extends StatefulWidget {
  final List<DocumentPreviewData> documents;
  final int initialIndex;
  final VoidCallback? onClose;
  final VoidCallback? onDownload;

  const DocumentPreviewScreen({
    super.key,
    required this.documents,
    this.initialIndex = 0,
    this.onClose,
    this.onDownload,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.documents.length - 1);
  }

  void _previousDocument() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _nextDocument() {
    if (_currentIndex < widget.documents.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documents[_currentIndex];
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? screenW : 960,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Blue header
              _buildHeader(),
              // Content
              Expanded(
                child: isMobile
                    ? _buildMobileLayout(doc)
                    : _buildDesktopLayout(doc),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Blue header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.preview_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Document Preview',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose ?? () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop: side-by-side ─────────────────────────────────────────
  Widget _buildDesktopLayout(DocumentPreviewData doc) {
    return Row(
      children: [
        // Left: image preview
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFFF3F4F6),
            child: _buildImageSection(doc),
          ),
        ),
        Container(width: 1, color: AppColors.border),
        // Right: details
        Expanded(
          flex: 2,
          child: _buildRightPanel(doc),
        ),
      ],
    );
  }

  // ── Mobile: stacked ───────────────────────────────────────────────
  Widget _buildMobileLayout(DocumentPreviewData doc) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            color: const Color(0xFFF3F4F6),
            child: _buildImageSection(doc),
          ),
        ),
        Container(height: 1, color: AppColors.border),
        Expanded(
          flex: 2,
          child: _buildRightPanel(doc),
        ),
      ],
    );
  }

  // ── Image section with nav arrows ─────────────────────────────────
  Widget _buildImageSection(DocumentPreviewData doc) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                doc.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildImageError(),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  final pct = progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null;
                  return Center(
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.documents.length > 1) ...[
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavArrow(
                Icons.chevron_left,
                _currentIndex > 0,
                _previousDocument,
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavArrow(
                Icons.chevron_right,
                _currentIndex < widget.documents.length - 1,
                _nextDocument,
              ),
            ),
          ),
        ],
        if (widget.documents.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),
      ],
    );
  }

  Widget _buildNavArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withOpacity(0.95)
                : Colors.white.withOpacity(0.4),
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.documents.length, (i) {
        final isActive = i == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.textTertiary.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildImageError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Unable to load image',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Right panel ───────────────────────────────────────────────────
  Widget _buildRightPanel(DocumentPreviewData doc) {
    return Container(
      color: AppColors.cardBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Details',
              style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            // Filename
            _buildInfoRow(
              icon: Icons.insert_drive_file_outlined,
              label: 'Filename',
              value: doc.filename,
            ),
            const SizedBox(height: 14),
            // Date
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: doc.date ?? 'N/A',
            ),
            const SizedBox(height: 14),
            // Status
            _buildInfoRow(
              icon: Icons.verified_outlined,
              label: 'Status',
              trailing: _buildStatusChip(doc.isPassed),
            ),
            // Failure reason
            if (!doc.isPassed && doc.failureReason != null) ...[
              const SizedBox(height: 14),
              _buildFailureCard(doc.failureReason!),
            ],
            const SizedBox(height: 28),
            // Download button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  textStyle: AppTextStyles.buttonSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info row ──────────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (value != null)
                  Text(
                    value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────────────────
  Widget _buildStatusChip(bool isPassed) {
    final bgColor = isPassed ? AppColors.approvedBackground : AppColors.rejectedBackground;
    final fgColor = isPassed ? AppColors.approvedText : AppColors.rejectedText;
    final borderColor = isPassed ? AppColors.approvedBorder : AppColors.rejectedBorder;
    final icon = isPassed ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final label = isPassed ? 'Pass' : 'Fail';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Failure card ──────────────────────────────────────────────────
  Widget _buildFailureCard(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rejectedBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rejectedBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.rejectedText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failure Reason',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.rejectedText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.rejectedText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
