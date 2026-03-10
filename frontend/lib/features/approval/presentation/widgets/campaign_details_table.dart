import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';

/// Table widget displaying campaign details (Invoice, Photo, CostSummary, Activity).
/// Matches the PO table layout: S.No, Category, Document Name, Status, Remarks.
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
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
          _buildTable(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      border: const TableBorder(
        horizontalInside: BorderSide(color: AppColors.border),
        top: BorderSide(color: AppColors.border),
      ),
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(2),
        3: FixedColumnWidth(80),
        4: FlexColumnWidth(3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildHeaderRow(),
        ...campaignDetails.asMap().entries.map((entry) {
          return _buildDataRow(entry.value, entry.key);
        }),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return const TableRow(
      decoration: BoxDecoration(color: AppColors.primary),
      children: [
        _HeaderCell('S.No'),
        _HeaderCell('Category'),
        _HeaderCell('Document Name'),
        _HeaderCell('Status'),
        _HeaderCell('Remarks'),
      ],
    );
  }

  TableRow _buildDataRow(CampaignDetailRow detail, int index) {
    final bg = index % 2 == 0 ? Colors.white : AppColors.background;
    // Use dealerName field as category (set by transformer)
    final category = _displayCategory(detail.dealerName);

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        _DataCell(detail.serialNumber.toString()),
        _DataCell(category),
        _buildDocumentNameCell(detail),
        _buildStatusCell(detail.status),
        _DataCell(detail.remarks),
      ],
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

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
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
}

class _DataCell extends StatelessWidget {
  final String text;
  const _DataCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium,
        softWrap: true,
      ),
    );
  }
}
