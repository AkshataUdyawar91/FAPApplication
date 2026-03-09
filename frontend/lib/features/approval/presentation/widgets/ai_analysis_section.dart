import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Collapsible AI Analysis section showing confidence score,
/// recommendation, and key findings from AI processing.
/// Redesigned for better readability and understanding by ASM users.
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
        recommendation?['type']?.toString().toUpperCase() ?? 'REVIEW';
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
        initiallyExpanded: true, // Show expanded by default for visibility
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
            validationResult: validationResult,
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
    required dynamic validationResult,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Recommendation Card - prominent and clear
        _buildRecommendationCard(recommendationType, confidencePercent, allPassed),
        const SizedBox(height: 20),

        // Quick Summary - what ASM needs to know
        _buildQuickSummary(confidencePercent, allPassed, recommendationType, validationResult),
        const SizedBox(height: 20),

        // Confidence breakdown with visual bars
        if (confidenceScore != null) ...[
          _buildConfidenceSection(confidenceScore),
          const SizedBox(height: 20),
        ],

        // Validation Checklist - easy to scan
        if (validationResult != null) ...[
          _buildValidationChecklist(validationResult),
          const SizedBox(height: 20),
        ],

        // Detailed findings (collapsible for advanced users)
        if (evidence.isNotEmpty)
          _buildDetailedFindings(evidence),

        // Validation failure details
        if (!allPassed && failureReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildValidationIssues(failureReason),
        ],
      ],
    );
  }

  /// Prominent recommendation card with clear action guidance
  Widget _buildRecommendationCard(String type, int confidence, bool allPassed) {
    final normalizedType = type.toLowerCase();
    
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    if (normalizedType == 'approve') {
      bgColor = const Color(0xFFD1FAE5);
      borderColor = const Color(0xFF10B981);
      textColor = const Color(0xFF065F46);
      icon = Icons.check_circle_rounded;
      title = '✓ Recommended for Approval';
      subtitle = 'High confidence score and all validations passed. This submission meets quality standards.';
    } else if (normalizedType == 'reject') {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFF991B1B);
      icon = Icons.cancel_rounded;
      title = '✗ Recommended for Rejection';
      subtitle = allPassed 
          ? 'Low confidence score indicates potential data quality issues. Manual review recommended.'
          : 'Validation failures detected. Please review the issues below before proceeding.';
    } else {
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFF92400E);
      icon = Icons.visibility_rounded;
      title = '⚠ Manual Review Recommended';
      subtitle = 'Moderate confidence score. Please review the details carefully before making a decision.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Quick summary with key metrics at a glance
  Widget _buildQuickSummary(int confidence, bool allPassed, String type, dynamic validationResult) {
    final passedChecks = _countPassedValidations(validationResult);
    final totalChecks = 6; // SAP, Amount, LineItems, Completeness, Date, Vendor
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary at a Glance',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  icon: Icons.speed_rounded,
                  label: 'AI Confidence',
                  value: '$confidence%',
                  color: confidence >= 85
                      ? const Color(0xFF10B981)
                      : confidence >= 70
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryMetric(
                  icon: Icons.checklist_rounded,
                  label: 'Validations',
                  value: '$passedChecks/$totalChecks Passed',
                  color: passedChecks == totalChecks
                      ? const Color(0xFF10B981)
                      : passedChecks >= 4
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryMetric(
                  icon: _getRecommendationIcon(type),
                  label: 'AI Decision',
                  value: _formatRecommendationType(type),
                  color: _getRecommendationColor(type),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Confidence breakdown with visual progress bars
  Widget _buildConfidenceSection(dynamic score) {
    final items = <_ConfidenceItem>[
      _ConfidenceItem('Purchase Order (PO)', score['poConfidence'], 0.30),
      _ConfidenceItem('Invoice', score['invoiceConfidence'], 0.30),
      _ConfidenceItem('Cost Summary', score['costSummaryConfidence'], 0.20),
      _ConfidenceItem('Activity Details', score['activityConfidence'], 0.10),
      _ConfidenceItem('Photos', score['photosConfidence'], 0.10),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Confidence Scores',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How confident the AI is about each document type',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildConfidenceBar(item)),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar(_ConfidenceItem item) {
    final percent = ((item.value is num ? item.value.toDouble() : 0.0) * 100).toInt();
    final color = percent >= 85
        ? const Color(0xFF10B981)
        : percent >= 70
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final weightPercent = (item.weight * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$weightPercent% weight',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  /// Validation checklist with clear pass/fail indicators
  Widget _buildValidationChecklist(dynamic validationResult) {
    final checks = [
      _ValidationCheck(
        'SAP Verification',
        'PO exists in SAP system',
        validationResult?['sapVerificationPassed'] == true,
      ),
      _ValidationCheck(
        'Amount Consistency',
        'Invoice amount matches PO amount',
        validationResult?['amountConsistencyPassed'] == true,
      ),
      _ValidationCheck(
        'Line Item Matching',
        'Invoice items match PO items',
        validationResult?['lineItemMatchingPassed'] == true,
      ),
      _ValidationCheck(
        'Completeness Check',
        'All required documents present',
        validationResult?['completenessCheckPassed'] == true,
      ),
      _ValidationCheck(
        'Date Validation',
        'Document dates are valid',
        validationResult?['dateValidationPassed'] == true,
      ),
      _ValidationCheck(
        'Vendor Matching',
        'Vendor details match across documents',
        validationResult?['vendorMatchingPassed'] == true,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validation Checklist',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Automated checks performed on the submission',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...checks.map((check) => _buildValidationCheckRow(check)),
        ],
      ),
    );
  }

  Widget _buildValidationCheckRow(_ValidationCheck check) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: check.passed
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              check.passed ? Icons.check : Icons.close,
              size: 16,
              color: check.passed
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.name,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: check.passed
                        ? AppColors.textPrimary
                        : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  check.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: check.passed
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              check.passed ? 'PASSED' : 'FAILED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: check.passed
                    ? const Color(0xFF065F46)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Detailed findings in a collapsible section
  Widget _buildDetailedFindings(String evidence) {
    // Parse the evidence to extract meaningful sections
    final sections = _parseEvidence(evidence);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          'Detailed AI Analysis',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        subtitle: Text(
          'Click to expand full AI-generated analysis',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          ...sections.map((section) => _buildEvidenceSection(section)),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection(_EvidenceSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty) ...[
            Text(
              section.title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...section.points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    point,
                    style: AppTextStyles.bodySmall.copyWith(
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildValidationIssues(String failureReason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Issues Requiring Attention',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            failureReason,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF991B1B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _countPassedValidations(dynamic validationResult) {
    if (validationResult == null) return 0;
    int count = 0;
    if (validationResult['sapVerificationPassed'] == true) count++;
    if (validationResult['amountConsistencyPassed'] == true) count++;
    if (validationResult['lineItemMatchingPassed'] == true) count++;
    if (validationResult['completenessCheckPassed'] == true) count++;
    if (validationResult['dateValidationPassed'] == true) count++;
    if (validationResult['vendorMatchingPassed'] == true) count++;
    return count;
  }

  IconData _getRecommendationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'approve':
        return Icons.thumb_up_rounded;
      case 'reject':
        return Icons.thumb_down_rounded;
      default:
        return Icons.visibility_rounded;
    }
  }

  Color _getRecommendationColor(String type) {
    switch (type.toLowerCase()) {
      case 'approve':
        return const Color(0xFF10B981);
      case 'reject':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatRecommendationType(String type) {
    switch (type.toLowerCase()) {
      case 'approve':
        return 'Approve';
      case 'reject':
        return 'Reject';
      default:
        return 'Review';
    }
  }

  List<_EvidenceSection> _parseEvidence(String evidence) {
    final sections = <_EvidenceSection>[];
    final lines = evidence.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    String currentTitle = '';
    List<String> currentPoints = [];
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Check if this is a section header (ends with : or is all caps)
      if (trimmed.endsWith(':') || 
          (trimmed == trimmed.toUpperCase() && trimmed.length > 3 && !trimmed.startsWith('-'))) {
        // Save previous section if exists
        if (currentPoints.isNotEmpty || currentTitle.isNotEmpty) {
          sections.add(_EvidenceSection(currentTitle, currentPoints));
        }
        currentTitle = trimmed.replaceAll(':', '');
        currentPoints = [];
      } else if (trimmed.startsWith('-') || trimmed.startsWith('•') || trimmed.startsWith('*')) {
        // This is a bullet point
        currentPoints.add(trimmed.substring(1).trim());
      } else {
        // Regular text - add as a point
        currentPoints.add(trimmed);
      }
    }
    
    // Add last section
    if (currentPoints.isNotEmpty || currentTitle.isNotEmpty) {
      sections.add(_EvidenceSection(currentTitle, currentPoints));
    }
    
    // If no sections were created, create one with all content
    if (sections.isEmpty && lines.isNotEmpty) {
      sections.add(_EvidenceSection('', lines));
    }
    
    return sections;
  }
}

class _ConfidenceItem {
  final String label;
  final dynamic value;
  final double weight;
  const _ConfidenceItem(this.label, this.value, this.weight);
}

class _ValidationCheck {
  final String name;
  final String description;
  final bool passed;
  const _ValidationCheck(this.name, this.description, this.passed);
}

class _EvidenceSection {
  final String title;
  final List<String> points;
  const _EvidenceSection(this.title, this.points);
}
