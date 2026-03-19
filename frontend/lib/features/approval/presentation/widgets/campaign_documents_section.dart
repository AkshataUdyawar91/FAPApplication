import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_document_row.dart';

/// Section widget that displays campaign documents in the same table format
/// as "Invoice and Additional Docs" — columns: S.No, Category, Document Name,
/// Status, Remarks. Each doc is downloadable via the hierarchical API.
class CampaignDocumentsSection extends StatelessWidget {
  final List<Map<String, dynamic>> campaigns;
  final String token;
  final String failureReason;
  final bool allValidationsPassed;

  const CampaignDocumentsSection({
    super.key,
    required this.campaigns,
    required this.token,
    this.failureReason = '',
    this.allValidationsPassed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <_CampaignDocRow>[];
    int serial = 1;

    for (final campaign in campaigns) {
      final campaignId = campaign['campaignId']?.toString() ?? '';
      final invoices = (campaign['invoices'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final photos = (campaign['photos'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final costFile = campaign['costSummaryFileName']?.toString();
      final activityFile = campaign['activitySummaryFileName']?.toString();

      for (final inv in invoices) {
        rows.add(_CampaignDocRow(
          serialNumber: serial++,
          category: 'Invoice',
          documentName: inv['fileName']?.toString() ?? '-',
          downloadUrl:
              '/hierarchical/invoices/${inv['invoiceId']}/download',
          status: _getStatusForType('Invoice'),
          remarks: _getRemarksForType('Invoice'),
        ),);
      }

      for (final photo in photos) {
        rows.add(_CampaignDocRow(
          serialNumber: serial++,
          category: 'Photo',
          documentName: photo['fileName']?.toString() ?? '-',
          downloadUrl:
              '/hierarchical/photos/${photo['photoId']}/download',
          status: _getStatusForType('Photo'),
          remarks: _getRemarksForType('Photo'),
        ),);
      }

      if (costFile != null && costFile.isNotEmpty) {
        rows.add(_CampaignDocRow(
          serialNumber: serial++,
          category: 'Cost Summary',
          documentName: costFile,
          downloadUrl:
              '/hierarchical/campaigns/$campaignId/download/cost-summary',
          status: _getStatusForType('CostSummary'),
          remarks: _getRemarksForType('CostSummary'),
        ),);
      }

      if (activityFile != null && activityFile.isNotEmpty) {
        rows.add(_CampaignDocRow(
          serialNumber: serial++,
          category: 'Activity Summary',
          documentName: activityFile,
          downloadUrl:
              '/hierarchical/campaigns/$campaignId/download/activity-summary',
          status: _getStatusForType('Activity'),
          remarks: _getRemarksForType('Activity'),
        ),);
      }
    }

    if (rows.isEmpty) {
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
          _buildTable(context, rows),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<_CampaignDocRow> rows) {
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
        ...rows.asMap().entries.map((entry) {
          return _buildDataRow(context, entry.value, entry.key);
        }),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(color: AppColors.primary),
      children: [
        _headerCell('S.No'),
        _headerCell('Category'),
        _headerCell('Document Name'),
        _headerCell('Status'),
        _headerCell('Remarks'),
      ],
    );
  }

  Widget _headerCell(String text) {
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

  TableRow _buildDataRow(
    BuildContext context,
    _CampaignDocRow row,
    int index,
  ) {
    final bg = index % 2 == 0 ? Colors.white : AppColors.background;
    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        _dataCell(row.serialNumber.toString()),
        _dataCell(row.category),
        _documentNameCell(context, row),
        _statusCell(row.status),
        _dataCell(row.remarks),
      ],
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium,
        softWrap: true,
      ),
    );
  }

  Widget _documentNameCell(BuildContext context, _CampaignDocRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: () => _downloadFile(context, row.downloadUrl, row.documentName),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                row.documentName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCell(ValidationStatus status) {
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

  /// Maps validation category names to the document types they affect.
  /// Uses the same keyword-based mapping as SubmissionDataTransformer.
  
  ValidationStatus _getStatusForType(String docType) {
    if (allValidationsPassed) return ValidationStatus.ok;
    if (failureReason.isEmpty) return ValidationStatus.unknown;
    
    final remarks = _getRemarksForType(docType);
    if (remarks.isNotEmpty) return ValidationStatus.failed;
    return ValidationStatus.ok;
  }

  String _getRemarksForType(String docType) {
    if (allValidationsPassed || failureReason.isEmpty) return '';
    
    final messages = failureReason.split(';').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    final matched = <String>[];

    for (final msg in messages) {
      final lower = msg.toLowerCase();
      final types = _messageToDocTypes(lower);
      if (types.contains(docType)) {
        matched.add(msg);
      }
    }

    return matched.join('; ');
  }

  /// Maps a failure message (lowercase) to the document types it relates to.
  static List<String> _messageToDocTypes(String lowerMsg) {
    final types = <String>{};

    if (lowerMsg.contains('po line item') ||
        lowerMsg.contains('po amount') ||
        lowerMsg.contains('po number') ||
        lowerMsg.contains('po date') ||
        lowerMsg.contains('sap')) {
      types.add('PO');
    }

    if (lowerMsg.contains('invoice') ||
        lowerMsg.contains('gst') ||
        lowerMsg.contains('hsn') ||
        lowerMsg.contains('sac code') ||
        lowerMsg.contains('vendor code') ||
        lowerMsg.contains('vendor name') ||
        lowerMsg.contains('billing')) {
      types.add('Invoice');
    }

    if (lowerMsg.contains('po line item') && lowerMsg.contains('invoice')) {
      types.add('PO');
      types.add('Invoice');
    }

    if (lowerMsg.contains('invoice amount') && lowerMsg.contains('po amount')) {
      types.add('PO');
      types.add('Invoice');
    }

    if (lowerMsg.contains('missing required fields')) {
      if (lowerMsg.contains('vendor code') ||
          lowerMsg.contains('po number') ||
          lowerMsg.contains('invoice number') ||
          lowerMsg.contains('gst') ||
          lowerMsg.contains('hsn')) {
        types.add('Invoice');
      }
      if (lowerMsg.contains('element wise quantity') ||
          lowerMsg.contains('number of activations') ||
          lowerMsg.contains('number of days') ||
          lowerMsg.contains('number of teams') ||
          lowerMsg.contains('total cost') ||
          lowerMsg.contains('campaign')) {
        types.add('CostSummary');
      }
      if (lowerMsg.contains('activity') ||
          lowerMsg.contains('activation')) {
        types.add('Activity');
      }
    }

    if (lowerMsg.contains('photo') ||
        lowerMsg.contains('image') ||
        lowerMsg.contains('vehicle') ||
        lowerMsg.contains('blue t-shirt') ||
        lowerMsg.contains('branding') ||
        lowerMsg.contains('bajaj vehicle')) {
      types.add('Photo');
    }

    if (lowerMsg.contains('cost summary') ||
        lowerMsg.contains('cost breakdown') ||
        lowerMsg.contains('total cost')) {
      types.add('CostSummary');
    }

    if (lowerMsg.contains('activity') ||
        lowerMsg.contains('activation')) {
      types.add('Activity');
    }

    if (lowerMsg.contains('enquiry') || lowerMsg.contains('enquiry dump')) {
      types.add('EnquiryDump');
    }

    if (lowerMsg.contains('date') &&
        (lowerMsg.contains('before') || lowerMsg.contains('after') || lowerMsg.contains('future'))) {
      types.add('PO');
      types.add('Invoice');
    }

    if (types.isEmpty) {
      if (lowerMsg.contains('missing')) {
        types.add('PO');
        types.add('Invoice');
      }
    }

    return types.toList();
  }

  Future<void> _downloadFile(
    BuildContext context,
    String downloadUrl,
    String filename,
  ) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))..interceptors.add(PrettyDioLogger())..interceptors.add(PrettyDioLogger());
      final response = await dio.get(
        downloadUrl,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 404) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not available for "$filename"'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (response.statusCode == 200) {
        final base64Content =
            response.data['base64Content']?.toString() ?? '';
        final contentType = response.data['contentType']?.toString() ??
            'application/octet-stream';
        final name =
            response.data['filename']?.toString() ?? filename;

        if (base64Content.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File content not available'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final bytes = base64.decode(base64Content);
        final blob = web.Blob(
          [bytes.toJS].toJS,
          web.BlobPropertyBag(type: contentType),
        );
        final url = web.URL.createObjectURL(blob);

        final anchor =
            web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = url;
        anchor.download = name;
        anchor.click();

        web.URL.revokeObjectURL(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading $name...'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not available for download: $filename'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

class _CampaignDocRow {
  final int serialNumber;
  final String category;
  final String documentName;
  final String downloadUrl;
  final ValidationStatus status;
  final String remarks;

  const _CampaignDocRow({
    required this.serialNumber,
    required this.category,
    required this.documentName,
    required this.downloadUrl,
    this.status = ValidationStatus.unknown,
    this.remarks = '',
  });
}
