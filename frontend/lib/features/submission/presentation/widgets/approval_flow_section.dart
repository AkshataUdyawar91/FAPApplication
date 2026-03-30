import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shared approval flow widget used across Agency, ASM, and RA detail pages.
/// Shows a 3-step timeline (Submitted → CH Review → RA Review) with a
/// history section below.
class ApprovalFlowSection extends StatelessWidget {
  final Map<String, dynamic> submission;

  const ApprovalFlowSection({
    super.key,
    required this.submission,
  });

  @override
  Widget build(BuildContext context) {
    final state = submission['state']?.toString().toLowerCase() ?? '';
    final createdAt = submission['createdAt'];
    final asmReviewedAt = submission['asmReviewedAt'];
    final hqReviewedAt = submission['hqReviewedAt'];
    final approvalHistory =
        submission['approvalHistory'] as List<dynamic>? ?? [];
    final comments = submission['comments'] as List<dynamic>? ?? [];

    // Extract per-role: latest approver name, last rejection reason, latest CH action
    String? asmApproverName;
    String? raApproverName;
    String? asmLastRejection;
    String? raLastRejection;
    String? latestCHAction; // Track what CH actually did (approved/rejected/resubmitted)
    for (final h in approvalHistory.reversed) {
      final entry = h as Map<String, dynamic>;
      final role = entry['approverRole']?.toString().toLowerCase() ?? '';
      final action = entry['action']?.toString().toLowerCase() ?? '';
      if (role == 'asm') {
        asmApproverName ??= entry['approverName']?.toString();
        latestCHAction ??= action; // First match in reversed = latest
        if (asmLastRejection == null && action.contains('rejected')) {
          asmLastRejection = entry['comments']?.toString();
        }
      }
      if (role == 'ra') {
        raApproverName ??= entry['approverName']?.toString();
        if (raLastRejection == null && action.contains('rejected')) {
          raLastRejection = entry['comments']?.toString();
        }
      }
    }

    // Determine ASM status based on the actual CH action from history
    String asmStatus = 'pending';
    if (state == 'chrejected' || state == 'rejectedbyasm') {
      asmStatus = 'rejected';
    } else if (state == 'pendingchreason' || state == 'pendingchclarification') {
      asmStatus = 'asked-reason';
    } else if (state == 'approved' ||
        state == 'pendingra' ||
        state == 'pendinghqapproval' ||
        state == 'rarejected' ||
        state == 'rejectedbyhq' ||
        state == 'rejectedbyra' ||
        state == 'pendingrareasonresponse' ||
        state == 'pendingraclarificationresponse') {
      // Check actual CH action from history — if CH rejected, show rejected
      if (latestCHAction != null && latestCHAction.contains('rejected')) {
        asmStatus = 'rejected';
      } else {
        asmStatus = 'approved';
      }
    } else if (asmReviewedAt != null) {
      asmStatus = 'approved';
    }

    // Determine HQ/RA status based on the status visibility matrix
    String hqStatus = 'pending';
    if (state == 'approved') {
      hqStatus = 'approved';
    } else if (state == 'rarejected') {
      hqStatus = 'rejected';
    } else if (state == 'pendingchreason' || state == 'pendingchclarification') {
      hqStatus = 'asked-reason'; // RA asked CH for reason, waiting for response
    } else if (state == 'pendingrareasonresponse' || state == 'pendingraclarificationresponse') {
      hqStatus = 'reason-received'; // CH responded, RA needs to review
    } else if (state == 'chrejected') {
      hqStatus = 'ch-rejected'; // CH rejected, RA can act
    } else if (hqReviewedAt != null) {
      hqStatus = 'approved';
    }

    // No comment bubbles on timeline steps — History section shows all details

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text('Approval Flow', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 20),
            _buildTimelineStep(
              icon: Icons.upload_file,
              color: const Color(0xFF3B82F6),
              title: 'Submitted',
              date: _formatDate(createdAt),
              isCompleted: true,
              isLast: false,
            ),
            _buildTimelineStep(
              icon: asmStatus == 'approved'
                  ? Icons.check_circle
                  : asmStatus == 'rejected'
                      ? Icons.cancel
                      : asmStatus == 'asked-reason'
                          ? Icons.question_answer
                          : Icons.schedule,
              color: asmStatus == 'approved'
                  ? const Color(0xFF10B981)
                  : asmStatus == 'rejected'
                      ? const Color(0xFFDC2626)
                      : asmStatus == 'asked-reason'
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF9CA3AF),
              title: asmStatus == 'approved'
                  ? 'Approved by CH${asmApproverName != null ? ' ($asmApproverName)' : ''}'
                  : asmStatus == 'rejected'
                      ? 'Rejected by CH${asmApproverName != null ? ' ($asmApproverName)' : ''}'
                      : asmStatus == 'asked-reason'
                          ? 'RA Asked Reason'
                          : 'Pending CH Review',
              date: asmReviewedAt != null ? _formatDate(asmReviewedAt) : null,
              isCompleted: asmStatus != 'pending',
              isLast: false,
            ),
            _buildTimelineStep(
              icon: hqStatus == 'approved'
                  ? Icons.check_circle
                  : hqStatus == 'rejected'
                      ? Icons.cancel
                      : hqStatus == 'asked-reason'
                          ? Icons.question_answer
                          : hqStatus == 'reason-received'
                              ? Icons.mark_email_read
                              : hqStatus == 'ch-rejected'
                                  ? Icons.warning_amber
                                  : Icons.schedule,
              color: hqStatus == 'approved'
                  ? const Color(0xFF10B981)
                  : hqStatus == 'rejected'
                      ? const Color(0xFFDC2626)
                      : hqStatus == 'asked-reason'
                          ? const Color(0xFFF59E0B)
                          : hqStatus == 'reason-received'
                              ? const Color(0xFFDC2626)
                              : hqStatus == 'ch-rejected'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF9CA3AF),
              title: hqStatus == 'approved'
                  ? 'Approved by RA${raApproverName != null ? ' ($raApproverName)' : ''}'
                  : hqStatus == 'rejected'
                      ? 'Rejected by RA${raApproverName != null ? ' ($raApproverName)' : ''}'
                      : hqStatus == 'asked-reason'
                          ? 'Asked Reason (Waiting for CH)'
                          : hqStatus == 'reason-received'
                              ? 'CH Responded'
                              : hqStatus == 'ch-rejected'
                                  ? 'CH Rejected'
                                  : 'Pending RA Review',
              date: hqReviewedAt != null ? _formatDate(hqReviewedAt) : null,
              isCompleted: hqStatus != 'pending',
              isLast: true,
            ),

            // History section
            if (approvalHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('History',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...approvalHistory.reversed.map((h) =>
                  _buildHistoryEntry(h as Map<String, dynamic>)),
            ],
            // Standalone comments from RequestComments
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Comments',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...comments.map((c) =>
                  _buildCommentEntry(c as Map<String, dynamic>)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(Map<String, dynamic> entry) {
    final action = entry['action']?.toString() ?? '';
    final role = entry['approverRole']?.toString() ?? '';
    final name = entry['approverName']?.toString() ?? role;
    final comments = entry['comments']?.toString();
    final date = entry['actionDate'];

    final isApproved = action.toLowerCase().contains('approved');
    final isRejected = action.toLowerCase().contains('rejected');
    final isSentBackToCH = action.toLowerCase().contains('sentbacktoch');
    final roleLabel = role == 'ASM' ? 'CH' : role;

    // Friendly display for SentBackToCH action
    final displayAction = isSentBackToCH ? 'Clarification requested' : action;
    final displayLabel = name.isNotEmpty && name != role
        ? '$displayAction by $roleLabel ($name)'
        : '$displayAction by $roleLabel';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isApproved
                ? Icons.check_circle_outline
                : isRejected
                    ? Icons.highlight_off
                    : isSentBackToCH
                        ? Icons.question_answer
                        : Icons.info_outline,
            size: 16,
            color: isApproved
                ? const Color(0xFF10B981)
                : isRejected
                    ? const Color(0xFFDC2626)
                    : isSentBackToCH
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayLabel,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                if (date != null)
                  Text(_formatDate(date),
                      style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11, color: AppColors.textSecondary)),
                if (comments != null && comments.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? const Color(0xFFFEF2F2)
                          : isSentBackToCH
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: isRejected
                              ? const Color(0xFFFCA5A5)
                              : isSentBackToCH
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRejected)
                          const Padding(
                            padding: EdgeInsets.only(right: 6, top: 1),
                            child: Icon(Icons.error_outline,
                                size: 14, color: Color(0xFFDC2626)),
                          ),
                        Expanded(
                          child: Text(comments,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: isRejected
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF4B5563),
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentEntry(Map<String, dynamic> entry) {
    final userName = entry['userName']?.toString() ?? '';
    final userRole = entry['userRole']?.toString() ?? '';
    final commentText = entry['commentText']?.toString() ?? '';
    final commentDate = entry['commentDate'];
    final roleLabel = userRole == 'ASM' ? 'CH' : userRole;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline,
              size: 16, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    userName.isNotEmpty
                        ? '$roleLabel ($userName)'
                        : roleLabel,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                if (commentDate != null)
                  Text(_formatDate(commentDate),
                      style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11, color: AppColors.textSecondary)),
                if (commentText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(commentText,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFF4B5563), height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color color,
    required String title,
    String? date,
    String? rejectionReason,
    String? comment,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? color.withOpacity(0.15)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isCompleted ? color : const Color(0xFFD1D5DB),
                        width: 2),
                  ),
                  child: Icon(icon,
                      size: 14,
                      color: isCompleted ? color : const Color(0xFF9CA3AF)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? color.withOpacity(0.3)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF))),
                  if (date != null) ...[
                    const SizedBox(height: 2),
                    Text(date,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                  if (rejectionReason != null &&
                      rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 6, top: 1),
                            child: Icon(Icons.error_outline,
                                size: 14, color: Color(0xFFDC2626)),
                          ),
                          Expanded(
                            child: Text(rejectionReason,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: const Color(0xFF991B1B),
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(comment,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF4B5563), height: 1.4)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return '';
    }
  }
}
