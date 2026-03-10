import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/approval_action_model.dart';

/// Renders an ordered list of [ApprovalActionModel] as a vertical timeline.
/// Each entry shows: actor name, role badge, action type icon, comment, and
/// formatted timestamp. Uses distinct colors per action type.
class ApprovalHistoryTimeline extends StatelessWidget {
  /// The list of approval actions to display, ordered by timestamp ascending.
  final List<ApprovalActionModel> actions;

  const ApprovalHistoryTimeline({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 40, color: AppColors.textTertiary),
              SizedBox(height: 8),
              Text(
                'No approval history yet',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < actions.length; i++)
          _TimelineEntry(
            action: actions[i],
            isLast: i == actions.length - 1,
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ApprovalActionModel action;
  final bool isLast;

  const _TimelineEntry({
    required this.action,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor = _colorForActionType(action.actionType);
    final actionIcon = _iconForActionType(action.actionType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: actionColor, width: 2),
                  ),
                  child: Icon(actionIcon, size: 14, color: actionColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Actor name + role badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            action.actorName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoleBadge(role: action.actorRole),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Action label
                    Text(
                      _labelForActionType(action.actionType),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: actionColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Comment
                    Text(
                      action.comment,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Timestamp
                    Text(
                      _formatTimestamp(action.actionTimestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForActionType(String actionType) {
    switch (actionType) {
      case 'ASMApproved':
      case 'RAApproved':
        return const Color(0xFF059669); // green
      case 'ASMRejected':
      case 'RARejected':
        return const Color(0xFFDC2626); // red
      case 'Resubmitted':
        return const Color(0xFFEA580C); // orange
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _iconForActionType(String actionType) {
    switch (actionType) {
      case 'ASMApproved':
      case 'RAApproved':
        return Icons.check_circle_outline;
      case 'ASMRejected':
      case 'RARejected':
        return Icons.cancel_outlined;
      case 'Resubmitted':
        return Icons.replay;
      default:
        return Icons.info_outline;
    }
  }

  String _labelForActionType(String actionType) {
    switch (actionType) {
      case 'ASMApproved':
        return 'ASM Approved';
      case 'ASMRejected':
        return 'ASM Rejected';
      case 'RAApproved':
        return 'RA Approved';
      case 'RARejected':
        return 'RA Rejected';
      case 'Resubmitted':
        return 'Resubmitted';
      default:
        return actionType;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('MMM dd, yyyy – hh:mm a').format(timestamp);
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _colorForRole(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  Color _colorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'asm':
        return const Color(0xFF003087); // Bajaj primary blue
      case 'hq':
      case 'ra':
        return const Color(0xFF7C3AED); // purple
      case 'agency':
        return const Color(0xFFEA580C); // orange
      default:
        return AppColors.textSecondary;
    }
  }
}
