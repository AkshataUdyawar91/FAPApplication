import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';

/// Table widget displaying campaign details (photos) grouped by dealer.
/// 
/// Shows photos in a table with columns: S.No, Dealer Name, Campaign Date,
/// Document Name, Status, Remarks. Visual grouping for dealer rows.
/// 
/// Requirements: 4.1, 4.2, 4.5, 4.6, 4.7, 4.8, 4.9
class CampaignDetailsTable extends StatelessWidget {
  /// List of campaign detail rows to display.
  final List<CampaignDetailRow> campaignDetails;
  
  /// Callback when a photo row is tapped.
  final void Function(CampaignDetailRow detail)? onPhotoTap;

  const CampaignDetailsTable({
    super.key,
    required this.campaignDetails,
    this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (campaignDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Campaign Name',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Table with horizontal scroll support
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: _buildTable(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: AppColors.border),
        top: BorderSide(color: AppColors.border),
      ),
      columnWidths: const {
        0: FixedColumnWidth(60),   // S.No
        1: FlexColumnWidth(0.75),  // Campaign/Team
        2: FlexColumnWidth(0.75),  // Campaign Date
        3: FlexColumnWidth(2),     // Document Name
        4: FixedColumnWidth(100),  // Status
        5: FlexColumnWidth(2),     // Remarks
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header row
        _buildHeaderRow(),
        // Data rows
        ...campaignDetails.asMap().entries.map((entry) {
          final index = entry.key;
          final detail = entry.value;
          return _buildDataRow(detail, index);
        }),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
      children: [
        _buildHeaderCell('S.No'),
        _buildHeaderCell('Campaign/Team'),
        _buildHeaderCell('Campaign Date'),
        _buildHeaderCell('Document Name'),
        _buildHeaderCell('Status'),
        _buildHeaderCell('Remarks'),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  TableRow _buildDataRow(CampaignDetailRow detail, int index) {
    // Alternating row colors: even = white, odd = background
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Colors.white : AppColors.background;

    return TableRow(
      decoration: BoxDecoration(
        color: backgroundColor,
        // Add top border for first row of each dealer group
        border: detail.isFirstInGroup && index > 0
            ? Border(
                top: BorderSide(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              )
            : null,
      ),
      children: [
        _buildDataCell(detail.serialNumber.toString()),
        _buildDealerCell(detail),
        _buildDataCell(detail.campaignDate),
        _buildDocumentNameCell(detail),
        _buildStatusCell(detail.status),
        _buildDataCell(detail.remarks),
      ],
    );
  }

  Widget _buildDataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium,
      ),
    );
  }

  Widget _buildDealerCell(CampaignDetailRow detail) {
    // Show dealer name with visual emphasis for first row in group
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        detail.dealerName,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: detail.isFirstInGroup ? FontWeight.w600 : FontWeight.normal,
          color: detail.isFirstInGroup ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildDocumentNameCell(CampaignDetailRow detail) {
    final hasUrl = (detail.documentId != null && detail.documentId!.isNotEmpty) ||
        (detail.blobUrl != null && detail.blobUrl!.isNotEmpty);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: hasUrl && onPhotoTap != null 
            ? () => onPhotoTap!(detail) 
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image,
              size: 16,
              color: hasUrl ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                detail.documentName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasUrl ? AppColors.primary : AppColors.textPrimary,
                  decoration: hasUrl ? TextDecoration.underline : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCell(ValidationStatus status) {
    // If status is unknown, show empty space
    if (status == ValidationStatus.unknown) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SizedBox.shrink(),
      );
    }
    
    final isOk = status == ValidationStatus.ok;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Text(
            status.displayText,
            style: AppTextStyles.bodySmall.copyWith(
              color: isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
