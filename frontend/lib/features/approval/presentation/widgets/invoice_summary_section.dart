import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_summary_data.dart';

/// Widget displaying the invoice summary section.
/// 
/// Shows invoice amount, agency name, and submitted date in a card format.
/// Uses responsive layout (horizontal on desktop, vertical on mobile).
/// 
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
class InvoiceSummarySection extends StatelessWidget {
  /// The invoice summary data to display.
  final InvoiceSummaryData data;

  const InvoiceSummarySection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 500;
            
            if (isMobile) {
              return _buildVerticalLayout();
            }
            
            return _buildHorizontalLayout();
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryItem(
            label: 'Invoice Amount',
            value: data.invoiceAmount,
            icon: Icons.receipt_long,
            isPrimary: true,
          ),
        ),
        _buildDivider(),
        Expanded(
          child: _buildSummaryItem(
            label: 'Agency',
            value: data.agencyName,
            icon: Icons.business,
          ),
        ),
        _buildDivider(),
        Expanded(
          child: _buildSummaryItem(
            label: 'Submitted on',
            value: data.submittedDate,
            icon: Icons.calendar_today,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryItem(
          label: 'Invoice Amount',
          value: data.invoiceAmount,
          icon: Icons.receipt_long,
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildSummaryItem(
          label: 'Agency',
          value: data.agencyName,
          icon: Icons.business,
        ),
        const SizedBox(height: 16),
        _buildSummaryItem(
          label: 'Submitted on',
          value: data.submittedDate,
          icon: Icons.calendar_today,
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPrimary 
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isPrimary ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: isPrimary
                    ? AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      )
                    : AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.border,
    );
  }
}
