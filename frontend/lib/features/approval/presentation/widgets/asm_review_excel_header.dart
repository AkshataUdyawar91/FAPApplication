import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Header widget for the ASM Review Excel-based layout.
/// 
/// Displays back button, FAP ID, status badge, and action buttons
/// (Approve FAP, Reject FAP) in a horizontal layout.
/// 
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
class ASMReviewExcelHeader extends StatelessWidget {
  /// The FAP submission ID.
  final String submissionId;
  
  /// Current state of the submission (e.g., "PendingApproval", "RejectedByHQ").
  final String state;
  
  /// Whether an action is currently being processed.
  final bool isProcessing;
  
  /// Callback when back button is pressed.
  final VoidCallback onBack;
  
  /// Callback when Approve FAP button is pressed.
  final VoidCallback onApprove;
  
  /// Callback when Reject FAP button is pressed.
  final VoidCallback onReject;

  const ASMReviewExcelHeader({
    super.key,
    required this.submissionId,
    required this.state,
    required this.isProcessing,
    required this.onBack,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final fapId = 'FAP-${submissionId.length >= 8 ? submissionId.substring(0, 8).toUpperCase() : submissionId.toUpperCase()}';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          
          if (isMobile) {
            return _buildMobileLayout(fapId);
          }
          
          return _buildDesktopLayout(fapId);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(String fapId) {
    return Row(
      children: [
        // Back button
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to review list',
        ),
        const SizedBox(width: 12),
        
        // FAP ID
        Text(
          fapId,
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        
        // Status badge
        _buildStatusBadge(),
        
        const Spacer(),
        
        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildMobileLayout(String fapId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Back button
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to review list',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            
            // FAP ID
            Expanded(
              child: Text(
                fapId,
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Status badge
            _buildStatusBadge(),
          ],
        ),
        const SizedBox(height: 12),
        
        // Action buttons (full width on mobile)
        _buildActionButtons(fullWidth: true),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final normalizedState = state.toLowerCase();
    
    Color backgroundColor;
    Color textColor;
    String displayText;
    
    if (normalizedState == 'pendingapproval' || normalizedState == 'pending') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
      displayText = 'Pending Review';
    } else if (normalizedState == 'approved') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF10B981);
      displayText = 'Approved';
    } else if (normalizedState == 'rejectedbyhq') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected by HQ';
    } else if (normalizedState == 'rejected') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected';
    } else {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
      displayText = state;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayText,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons({bool fullWidth = false}) {
    if (fullWidth) {
      return Row(
        children: [
          Expanded(
            child: _buildApproveButton(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRejectButton(),
          ),
        ],
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildApproveButton(),
        const SizedBox(width: 12),
        _buildRejectButton(),
      ],
    );
  }

  Widget _buildApproveButton() {
    return ElevatedButton.icon(
      onPressed: isProcessing ? null : onApprove,
      icon: isProcessing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_circle, size: 18),
      label: Text(isProcessing ? 'Processing...' : 'Approve FAP'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildRejectButton() {
    return OutlinedButton.icon(
      onPressed: isProcessing ? null : onReject,
      icon: const Icon(Icons.cancel, size: 18),
      label: const Text('Reject FAP'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: const BorderSide(color: Color(0xFFEF4444)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
