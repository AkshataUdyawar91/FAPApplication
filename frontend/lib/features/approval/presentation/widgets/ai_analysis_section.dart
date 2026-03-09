import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Collapsible AI Analysis section showing confidence score,
/// recommendation, and key findings from AI processing.
class AiAnalysisSection extends StatelessWidget {
  /// Raw submission data map containing confidenceScore, recommendation,
  /// and validationResult fields.
  final Map<String, dynamic> submission;

  const AiAnalysisSection({
    super.key,
    required this.submission,
  });

  @override
  Widget build(BuildContext context) {
    final confidenceScore = submission['confidenceScore'];
    final recommendation = submission['recommendation'];
    final validationResult = submission['validationResult'];

    // Don't render if no AI data at all
    if (confidenceScore == null && recommendation == null) {
      return const SizedBox.shrink();
    }

    final overallConfidence = confidenceScore?['overallConfidence'] ?? 0.0;
    final confidencePercent =
        ((overallConfidence is num ? overallConfidence.toDouble() : 0.0) * 100)
            .toInt();

    final recommendationType =
        recommendation?['type']?.toString() ?? 'REVIEW';
    final evidence = recommendation?['evidence']?.toString() ?? '';
    final allPassed =
        validationResult?['allValidationsPassed'] == true;
    final failureReason =
        validationResult?['failureReason']?.toString() ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        backgroundColor: const Color(0xFFEFF6FF),
        collapsedBackgroundColor: const Color(0xFFEFF6FF),
        leading: Icon(Icons.psychology, color: AppColors.primary, size: 22),
        title: Row(
          children: [
            Text(
              'AI Analysis',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            _buildConfidenceBadge(confidencePercent),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildContent(
            confidencePercent: confidencePercent,
            confidenceScore: confidenceScore,
            recommendationType: recommendationType,
            evidence: evidence,
            allPassed: allPassed,
            failureReason: failureReason,
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(int percent) {
    final color = percent >= 85
        ? const Color(0xFF10B981)
        : percent >= 70
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$percent% Confidence',
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildContent({
    required int confidencePercent,
    required dynamic confidenceScore,
    required String recommendationType,
    required String evidence,
    required bool allPassed,
    required String failureReason,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommendation row
        _buildRecommendationRow(recommendationType, allPassed),
        const SizedBox(height: 16),

        // Confidence breakdown
        if (confidenceScore != null) ...[
          Text(
            'Confidence Breakdown',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildConfidenceBreakdown(confidenceScore),
          const SizedBox(height: 16),
        ],

        // Key findings / evidence
        if (evidence.isNotEmpty) ...[
          Text(
            'Key Findings',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...evidence
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .map((line) => _buildFindingPoint(line.trim())),
        ],

        // Validation failure details
        if (!allPassed && failureReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Validation Issues',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFECACA),
              ),
            ),
            child: Text(
              failureReason,
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecommendationRow(String type, bool allPassed) {
    final normalizedType = type.toLowerCase();
    final Color color;
    final IconData icon;

    if (normalizedType == 'approve') {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle;
    } else if (normalizedType == 'reject') {
      color = const Color(0xFFEF4444);
      icon = Icons.cancel;
    } else {
      color = const Color(0xFFF59E0B);
      icon = Icons.info;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          'AI Recommendation: ',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          type,
          style: AppTextStyles.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          allPassed ? Icons.verified : Icons.warning_amber_rounded,
          color: allPassed
              ? const Color(0xFF10B981)
              : const Color(0xFFF59E0B),
          size: 18,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            allPassed
                ? 'All validations passed'
                : 'Validation issues detected',
            style: AppTextStyles.bodyMedium.copyWith(
              color: allPassed
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBreakdown(dynamic score) {
    final items = <_ConfidenceItem>[
      _ConfidenceItem('PO', score['poConfidence']),
      _ConfidenceItem('Invoice', score['invoiceConfidence']),
      _ConfidenceItem('Cost Summary', score['costSummaryConfidence']),
      _ConfidenceItem('Activity', score['activityConfidence']),
      _ConfidenceItem('Photos', score['photosConfidence']),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        final percent =
            ((item.value is num ? item.value.toDouble() : 0.0) * 100).toInt();
        final color = percent >= 85
            ? const Color(0xFF10B981)
            : percent >= 70
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

        return SizedBox(
          width: 140,
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  item.label,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Text(
                '$percent%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFindingPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceItem {
  final String label;
  final dynamic value;
  const _ConfidenceItem(this.label, this.value);
}
