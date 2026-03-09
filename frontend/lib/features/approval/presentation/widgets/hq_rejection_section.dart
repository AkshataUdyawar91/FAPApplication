import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Widget displaying HQ rejection information and resubmit option.
/// 
/// Shows rejection reason, date, and a button to resubmit to HQ.
/// Only visible when the submission state is "RejectedByHQ".
/// 
/// Requirements: 6.3, 6.4
class HQRejectionSection extends StatelessWidget {
  /// The current state of the submission.
  final String state;
  
  /// The date when HQ reviewed/rejected the submission.
  final String? hqReviewedAt;
  
  /// The rejection notes/reason from HQ.
  final String? hqReviewNotes;
  
  /// Callback when Resubmit to HQ button is pressed.
  final VoidCallback onResubmit;

  const HQRejectionSection({
    super.key,
    required this.state,
    this.hqReviewedAt,
    this.hqReviewNotes,
    required this.onResubmit,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if rejected by HQ
    final normalizedState = state.toLowerCase();
    if (normalizedState != 'rejectedbyhq' || hqReviewedAt == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: const Color(0xFFFEE2E2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.cancel,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rejected by HQ',
                  style: AppTextStyles.h3.copyWith(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Rejection date
            Text(
              'Rejected on: ${_formatDate(hqReviewedAt)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFB91C1C),
              ),
            ),
            
            // Rejection reason
            if (hqReviewNotes != null && hqReviewNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'HQ Rejection Reason:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB91C1C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hqReviewNotes!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: const Color(0xFF7F1D1D),
                ),
              ),
            ],
            const SizedBox(height: 12),
            
            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please review HQ feedback and resubmit if appropriate.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Resubmit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onResubmit,
                icon: const Icon(Icons.send),
                label: const Text('Resubmit to HQ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
