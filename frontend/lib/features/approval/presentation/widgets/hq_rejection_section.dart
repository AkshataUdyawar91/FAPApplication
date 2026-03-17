import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Widget displaying RA rejection information and send back option.
/// 
/// Shows rejection reason, date, and a button to send back to Agency.
/// Only visible when the submission state is "RejectedByRA" (RejectedByHQ).
/// 
/// Requirements: Requirement 25 - Simplified approval workflow
class HQRejectionSection extends StatelessWidget {
  /// The current state of the submission.
  final String state;
  
  /// The date when RA reviewed/rejected the submission.
  final String? hqReviewedAt;
  
  /// The rejection notes/reason from RA.
  final String? hqReviewNotes;
  
  /// Callback when Resubmit to HQ button is pressed (DEPRECATED - not used in simplified flow).
  final VoidCallback onResubmit;

  /// Callback when Send Back to Agency button is pressed.
  final VoidCallback? onSendBackToAgency;

  const HQRejectionSection({
    super.key,
    required this.state,
    this.hqReviewedAt,
    this.hqReviewNotes,
    required this.onResubmit,
    this.onSendBackToAgency,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if rejected by RA (RejectedByHQ state)
    final normalizedState = state.toLowerCase();
    if (normalizedState != 'rejectedbyhq' && normalizedState != 'rejectedbyra' || hqReviewedAt == null) {
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
                  'Rejected by RA',
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
                'RA Rejection Reason:',
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
                      'You can resubmit to RA with corrections or send back to Agency for major revisions.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Action buttons - Resubmit to RA and Send Back to Agency
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onResubmit,
                    icon: const Icon(Icons.send),
                    label: const Text('Resubmit to RA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSendBackToAgency,
                    icon: const Icon(Icons.reply),
                    label: const Text('Send Back to Agency'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
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
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
