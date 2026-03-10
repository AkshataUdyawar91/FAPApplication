import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Horizontal stepper showing the approval workflow stages:
/// PendingASMApproval → PendingRAApproval → Approved.
/// Highlights the current stage and shows rejected states with red.
class WorkflowStageIndicator extends StatelessWidget {
  /// The current package state string.
  final String currentState;

  const WorkflowStageIndicator({
    super.key,
    required this.currentState,
  });

  @override
  Widget build(BuildContext context) {
    final stages = _buildStages();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stages.length; i++) ...[
            Expanded(child: _buildStageItem(stages[i])),
            if (i < stages.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<_StageData> _buildStages() {
    final isRejectedByASM = currentState == 'RejectedByASM';
    final isRejectedByRA = currentState == 'RejectedByRA';

    return [
      _StageData(
        label: 'ASM Review',
        status: _resolveStageStatus(
          stageIndex: 0,
          isRejectedAtStage: isRejectedByASM,
        ),
      ),
      _StageData(
        label: 'RA Review',
        status: _resolveStageStatus(
          stageIndex: 1,
          isRejectedAtStage: isRejectedByRA,
        ),
      ),
      _StageData(
        label: 'Approved',
        status: currentState == 'Approved'
            ? _StageStatus.completed
            : _StageStatus.pending,
      ),
    ];
  }

  _StageStatus _resolveStageStatus({
    required int stageIndex,
    required bool isRejectedAtStage,
  }) {
    if (isRejectedAtStage) return _StageStatus.rejected;

    final stateOrder = _stateToOrder(currentState);

    if (stageIndex < stateOrder) return _StageStatus.completed;
    if (stageIndex == stateOrder) return _StageStatus.active;
    return _StageStatus.pending;
  }

  /// Maps the current state to a numeric order for comparison.
  int _stateToOrder(String state) {
    switch (state) {
      case 'PendingASMApproval':
      case 'RejectedByASM':
        return 0;
      case 'PendingHQApproval':
      case 'PendingRAApproval':
      case 'RejectedByRA':
        return 1;
      case 'Approved':
        return 2;
      default:
        return -1;
    }
  }

  Widget _buildStageItem(_StageData stage) {
    final color = _colorForStatus(stage.status);
    final icon = _iconForStatus(stage.status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          stage.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _colorForStatus(_StageStatus status) {
    switch (status) {
      case _StageStatus.completed:
        return const Color(0xFF059669); // green
      case _StageStatus.active:
        return const Color(0xFF003087); // Bajaj primary blue
      case _StageStatus.rejected:
        return const Color(0xFFDC2626); // red
      case _StageStatus.pending:
        return AppColors.textTertiary;
    }
  }

  IconData _iconForStatus(_StageStatus status) {
    switch (status) {
      case _StageStatus.completed:
        return Icons.check;
      case _StageStatus.active:
        return Icons.hourglass_bottom;
      case _StageStatus.rejected:
        return Icons.close;
      case _StageStatus.pending:
        return Icons.hourglass_empty;
    }
  }
}

enum _StageStatus { completed, active, rejected, pending }

class _StageData {
  final String label;
  final _StageStatus status;

  const _StageData({required this.label, required this.status});
}
