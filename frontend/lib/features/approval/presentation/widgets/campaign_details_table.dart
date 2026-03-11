import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';

/// Table widget displaying campaign details (Invoice, Photo, CostSummary, Activity).
/// Matches the PO table layout exactly: S.No, Category, Document Name, Status, Remarks.
class CampaignDetailsTable extends StatelessWidget {
  final List<CampaignDetailRow> campaignDetails;
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

    // Group rows by campaign name
    final grouped = <String, List<CampaignDetailRow>>{};
    for (var row in campaignDetails) {
      final key = row.campaignName ?? '';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(row);
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Campaign Details',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...grouped.entries.map((entry) {
            final campaignName = entry.key;
            final rows = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (campaignName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Campaign Name - $campaignName',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                _buildTable(rows),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTable(List<CampaignDetailRow> rows) {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: AppColors.border),
        top: BorderSide(color: AppColors.border),
      ),
      columnWidths: const {
        0: FixedColumnWidth(60),   // S. No
        1: FlexColumnWidth(1.2),   // Category
        2: FlexColumnWidth(2),     // Document Name
        3: FixedColumnWidth(120),  // Status
        4: FlexColumnWidth(3),     // Remarks
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildHeaderRow(),
        ...rows.asMap().entries.map((entry) {
          return _buildDataRow(entry.value, entry.key, entry.key + 1);
        }),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(color: AppColors.primary),
      children: [
        _buildHeaderCell('S. No'),
        _buildHeaderCell('Category'),
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

  TableRow _buildDataRow(CampaignDetailRow detail, int index, int displayNumber) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Colors.white : AppColors.background;
    final category = _displayCategory(detail.dealerName);

    return TableRow(
      decoration: BoxDecoration(color: backgroundColor),
      children: [
        _buildDataCell(displayNumber.toString()),
        _buildDataCell(category),
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
        softWrap: true,
      ),
    );
  }

  String _displayCategory(String type) {
    switch (type) {
      case 'CostSummary':
        return 'Cost Summary';
      case 'Activity':
        return 'Activity Summary';
      default:
        return type;
    }
  }

  Widget _buildDocumentNameCell(CampaignDetailRow detail) {
    final hasUrl = (detail.documentId != null && detail.documentId!.isNotEmpty) ||
        (detail.blobUrl != null && detail.blobUrl!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: hasUrl && onPhotoTap != null ? () => onPhotoTap!(detail) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description,
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
    if (status == ValidationStatus.unknown) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SizedBox.shrink(),
      );
    }
    final isOk = status == ValidationStatus.ok;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.displayText,
              style: AppTextStyles.bodySmall.copyWith(
                color: isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
