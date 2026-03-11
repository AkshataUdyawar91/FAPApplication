import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_document_row.dart';

/// Table widget displaying invoice and additional documents.
/// 
/// Shows documents in a table with columns: S.No, Category, Document Name,
/// Status, Remarks. Supports horizontal scrolling on mobile.
/// 
/// Requirements: 3.1, 3.2, 3.4, 3.5, 3.6, 3.7
class InvoiceDocumentsTable extends StatelessWidget {
  /// List of document rows to display.
  final List<InvoiceDocumentRow> documents;
  
  /// Callback when a document row is tapped.
  final void Function(InvoiceDocumentRow document)? onDocumentTap;

  const InvoiceDocumentsTable({
    super.key,
    required this.documents,
    this.onDocumentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
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
              'PO and Additional Docs',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Table
          _buildTable(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth < 600 ? 600 : constraints.maxWidth),
            child: Table(
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
            // Header row
            _buildHeaderRow(),
            // Data rows
            ...documents.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              return _buildDataRow(doc, index);
            }),
          ],
            ),
          ),
        );
      },
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
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

  TableRow _buildDataRow(InvoiceDocumentRow doc, int index) {
    // Alternating row colors: even = white, odd = background
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Colors.white : AppColors.background;

    return TableRow(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      children: [
        _buildDataCell(doc.serialNumber.toString()),
        _buildDataCell(doc.category),
        _buildDocumentNameCell(doc),
        _buildStatusCell(doc.status),
        _buildDataCell(doc.remarks),
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

  Widget _buildDocumentNameCell(InvoiceDocumentRow doc) {
    final hasUrl = (doc.documentId != null && doc.documentId!.isNotEmpty) ||
        (doc.blobUrl != null && doc.blobUrl!.isNotEmpty);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: hasUrl && onDocumentTap != null 
            ? () => onDocumentTap!(doc) 
            : null,
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
                doc.documentName,
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
