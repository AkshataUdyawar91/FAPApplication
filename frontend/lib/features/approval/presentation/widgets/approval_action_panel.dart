import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Role-aware action panel for approval workflow.
/// Shows Approve/Reject buttons for ASM and RA roles,
/// Resubmit button for Agency role, with a mandatory comment field.
class ApprovalActionPanel extends StatefulWidget {
  /// The current user's role (e.g., 'ASM', 'HQ', 'Agency').
  final String userRole;

  /// The current package state string.
  final String currentState;

  /// Callback when the user approves with a comment.
  final void Function(String comment)? onApprove;

  /// Callback when the user rejects with a comment.
  final void Function(String comment)? onReject;

  /// Callback when the user resubmits with a comment.
  final void Function(String comment)? onResubmit;

  /// Whether an API call is in progress.
  final bool isLoading;

  /// The rejection reason to display for Agency users.
  final String? rejectionReason;

  /// The name of the reviewer who rejected the package.
  final String? rejectedBy;

  const ApprovalActionPanel({
    super.key,
    required this.userRole,
    required this.currentState,
    this.onApprove,
    this.onReject,
    this.onResubmit,
    this.isLoading = false,
    this.rejectionReason,
    this.rejectedBy,
  });

  @override
  State<ApprovalActionPanel> createState() => _ApprovalActionPanelState();
}

class _ApprovalActionPanelState extends State<ApprovalActionPanel> {
  final _commentController = TextEditingController();
  String? _commentError;

  static const int _maxCommentLength = 500;
  static const int _minCommentLength = 3;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool _validateComment() {
    final trimmed = _commentController.text.trim();
    if (trimmed.length < _minCommentLength) {
      setState(() {
        _commentError = 'Comment must be at least $_minCommentLength characters';
      });
      return false;
    }
    setState(() => _commentError = null);
    return true;
  }

  void _handleApprove() {
    if (!_validateComment()) return;
    widget.onApprove?.call(_commentController.text.trim());
  }

  void _handleReject() {
    if (!_validateComment()) return;
    widget.onReject?.call(_commentController.text.trim());
  }

  void _handleResubmit() {
    if (!_validateComment()) return;
    widget.onResubmit?.call(_commentController.text.trim());
  }

  bool get _isAgencyView => widget.userRole.toLowerCase() == 'agency';

  bool get _isReviewerView =>
      widget.userRole.toLowerCase() == 'asm' ||
      widget.userRole.toLowerCase() == 'hq';

  bool get _isRejectedState =>
      widget.currentState == 'RejectedByASM' ||
      widget.currentState == 'RejectedByRA';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rejection info for Agency view
          if (_isAgencyView && _isRejectedState) ...[
            _buildRejectionInfo(),
            const SizedBox(height: 16),
          ],

          // Comment field
          _buildCommentField(),
          const SizedBox(height: 16),

          // Action buttons
          if (_isReviewerView) _buildReviewerButtons(),
          if (_isAgencyView && _isRejectedState) _buildResubmitButton(),
        ],
      ),
    );
  }

  Widget _buildRejectionInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rejectedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rejectedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.rejectedText,
              ),
              const SizedBox(width: 8),
              Text(
                'Rejected by ${widget.rejectedBy ?? 'Reviewer'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rejectedText,
                ),
              ),
            ],
          ),
          if (widget.rejectionReason != null &&
              widget.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.rejectionReason!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.rejectedText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _commentController,
          maxLength: _maxCommentLength,
          maxLines: 3,
          enabled: !widget.isLoading,
          decoration: InputDecoration(
            labelText: 'Add your comment...',
            errorText: _commentError,
            counterText:
                '${_commentController.text.length}/$_maxCommentLength',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: (_) {
            // Clear error on typing and update counter
            if (_commentError != null) {
              setState(() => _commentError = null);
            } else {
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  Widget _buildReviewerButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.isLoading ? null : _handleApprove,
            icon: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.isLoading ? null : _handleReject,
            icon: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,),
                  )
                : const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.isLoading ? null : _handleResubmit,
        icon: widget.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,),
              )
            : const Icon(Icons.replay, size: 18),
        label: const Text('Resubmit'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
