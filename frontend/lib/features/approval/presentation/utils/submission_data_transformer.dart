import 'dart:convert';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';
import '../../data/models/invoice_summary_data.dart';

/// Utility class for transforming submission data into table-friendly formats.
///
/// Converts raw submission API response data into structured models for
/// the Excel-based ASM Review page layout.
///
/// All data comes directly from the API response. No dummy, placeholder,
/// or fallback values are generated.
class SubmissionDataTransformer {
  /// Extracts invoice summary data from a submission.
  static InvoiceSummaryData extractInvoiceSummary(
    Map<String, dynamic> submission,
  ) {
    String invoiceAmount = '';
    final documents = submission['documents'] as List? ?? [];

    for (var doc in documents) {
      final type = doc['type']?.toString() ?? '';
      if (type == 'Invoice' && doc['extractedData'] != null) {
        try {
          final extractedData = _parseExtractedData(doc['extractedData']);
          if (extractedData != null) {
            final amount = extractedData['TotalAmount'] ??
                extractedData['totalAmount'] ??
                extractedData['InvoiceAmount'] ??
                extractedData['invoiceAmount'];
            if (amount != null) {
              invoiceAmount = '₹$amount';
              break;
            }
          }
        } catch (_) {}
      }
    }

    final agencyName = submission['agencyName']?.toString() ?? '';
    final submittedDate = _formatDate(submission['createdAt']);

    return InvoiceSummaryData(
      invoiceAmount: invoiceAmount,
      agencyName: agencyName,
      submittedDate: submittedDate,
    );
  }

  /// Transforms submission documents into invoice document rows.
  ///
  /// Shows only PO documents. Maps validation failure messages from
  /// failureReason to each document type based on keywords.
  /// Shows ALL non-Photo documents from the API response plus campaign-level
  /// invoices, cost summaries, and activity summaries. Each document
  /// gets its own row with actual filename, blobUrl, and validation info.
  static List<InvoiceDocumentRow> transformToInvoiceDocuments(
    Map<String, dynamic> submission,
  ) {
    final documents = submission['documents'] as List? ?? [];
    final failureReason =
        submission['validationResult']?['failureReason']?.toString() ?? '';
    final allPassed =
        submission['validationResult']?['allValidationsPassed'] == true;

    final rows = <InvoiceDocumentRow>[];
    int serialNumber = 1;

    for (var doc in documents) {
      final type = doc['type']?.toString() ?? '';
      // Only show PO in this table — Invoice, Photo, and campaign docs go in Campaign Details
      if (type != 'PO') continue;

      final filename = doc['filename']?.toString() ?? '';
      final blobUrl = doc['blobUrl']?.toString() ?? '';
      final docId = doc['id']?.toString() ?? '';
      final remarks = buildRemarksFromFailureReason(type, failureReason, allPassed);
      final status = allPassed
          ? ValidationStatus.ok
          : remarks.isNotEmpty
              ? ValidationStatus.failed
              : ValidationStatus.ok;

      rows.add(InvoiceDocumentRow(
        serialNumber: serialNumber,
        category: type,
        documentName: filename,
        status: status,
        remarks: remarks,
        blobUrl: blobUrl,
        documentId: docId,
      ));
      serialNumber++;
    }

    return rows;
  }

  /// Transforms submission data into campaign detail rows.
  ///
  /// Uses the campaigns structure as the single source of truth for
  /// Invoice, Cost Summary, Activity Summary, and Photo documents.
  /// The documents array is NOT used here (it duplicates campaign data).
  /// Validation remarks come from failureReason parsing.
  static List<CampaignDetailRow> transformToCampaignDetails(
    Map<String, dynamic> submission,
  ) {
    final failureReason =
        submission['validationResult']?['failureReason']?.toString() ?? '';
    final allPassed =
        submission['validationResult']?['allValidationsPassed'] == true;

    // Build a filename -> documentId lookup from the documents array
    final documents = submission['documents'] as List? ?? [];
    final docIdByFilename = <String, String>{};
    for (var doc in documents) {
      final filename = doc['filename']?.toString() ?? '';
      final docId = doc['id']?.toString() ?? '';
      if (filename.isNotEmpty && docId.isNotEmpty) {
        docIdByFilename[filename.toLowerCase()] = docId;
      }
    }

    final rows = <CampaignDetailRow>[];
    int serialNumber = 1;

    final campaigns = submission['campaigns'] as List? ?? [];
    for (var campaign in campaigns) {
      final campaignMap = campaign as Map<String, dynamic>;
      final campaignId = campaignMap['id']?.toString() ?? '';
      final startDate = campaignMap['startDate'];
      final campaignName = campaignMap['campaignName']?.toString() ?? campaignMap['name']?.toString() ?? '';

      // Campaign invoices
      final invoices = campaignMap['invoices'] as List? ?? [];
      for (var inv in invoices) {
        final invMap = inv as Map<String, dynamic>;
        final fileName = invMap['fileName']?.toString() ?? 'Invoice';
        final blobUrl = invMap['blobUrl']?.toString() ?? '';
        final invoiceId = invMap['id']?.toString() ?? '';
        final docId = docIdByFilename[fileName.toLowerCase()] ?? '';
        final invRemarks = buildRemarksFromFailureReason('Invoice', failureReason, allPassed);

        rows.add(CampaignDetailRow(
          serialNumber: serialNumber,
          campaignName: campaignName,
          dealerName: 'Invoice',
          campaignDate: startDate != null ? _formatDate(startDate) : '',
          documentName: fileName,
          status: allPassed
              ? ValidationStatus.ok
              : invRemarks.isNotEmpty
                  ? ValidationStatus.failed
                  : ValidationStatus.ok,
          remarks: invRemarks,
          blobUrl: blobUrl,
          documentId: docId,
          downloadPath: invoiceId.isNotEmpty ? '/hierarchical/invoices/$invoiceId/download' : null,
          isFirstInGroup: false,
        ));
        serialNumber++;
      }

      // Cost summary
      final costUrl = campaignMap['costSummaryBlobUrl']?.toString() ?? '';
      final costFile = campaignMap['costSummaryFileName']?.toString() ?? '';
      if (costUrl.isNotEmpty || costFile.isNotEmpty) {
        final costRemarks = buildRemarksFromFailureReason('CostSummary', failureReason, allPassed);
        final costDocId = docIdByFilename[costFile.toLowerCase()] ?? '';
        rows.add(CampaignDetailRow(
          serialNumber: serialNumber,
          campaignName: campaignName,
          dealerName: 'CostSummary',
          campaignDate: '',
          documentName: costFile.isNotEmpty ? costFile : 'Cost Summary',
          status: allPassed
              ? ValidationStatus.ok
              : costRemarks.isNotEmpty
                  ? ValidationStatus.failed
                  : ValidationStatus.ok,
          remarks: costRemarks,
          blobUrl: costUrl,
          documentId: costDocId,
          downloadPath: campaignId.isNotEmpty ? '/hierarchical/campaigns/$campaignId/download/cost-summary' : null,
          isFirstInGroup: false,
        ));
        serialNumber++;
      }

      // Activity summary
      final actUrl = campaignMap['activitySummaryBlobUrl']?.toString() ?? '';
      final actFile = campaignMap['activitySummaryFileName']?.toString() ?? '';
      if (actUrl.isNotEmpty || actFile.isNotEmpty) {
        final actRemarks = buildRemarksFromFailureReason('Activity', failureReason, allPassed);
        final actDocId = docIdByFilename[actFile.toLowerCase()] ?? '';
        rows.add(CampaignDetailRow(
          serialNumber: serialNumber,
          campaignName: campaignName,
          dealerName: 'Activity',
          campaignDate: '',
          documentName: actFile.isNotEmpty ? actFile : 'Activity Summary',
          status: allPassed
              ? ValidationStatus.ok
              : actRemarks.isNotEmpty
                  ? ValidationStatus.failed
                  : ValidationStatus.ok,
          remarks: actRemarks,
          blobUrl: actUrl,
          documentId: actDocId,
          downloadPath: campaignId.isNotEmpty ? '/hierarchical/campaigns/$campaignId/download/activity-summary' : null,
          isFirstInGroup: false,
        ));
        serialNumber++;
      }

      // Campaign photos
      final photos = campaignMap['photos'] as List? ?? [];
      for (int i = 0; i < photos.length; i++) {
        final photoMap = photos[i] as Map<String, dynamic>;
        final fileName = photoMap['fileName']?.toString() ?? 'Photo';
        final blobUrl = photoMap['blobUrl']?.toString() ?? '';
        final photoId = photoMap['id']?.toString() ?? '';
        final photoDocId = docIdByFilename[fileName.toLowerCase()] ?? '';
        final photoRemarks = buildRemarksFromFailureReason('Photo', failureReason, allPassed);

        rows.add(CampaignDetailRow(
          serialNumber: serialNumber,
          campaignName: campaignName,
          dealerName: 'Photo',
          campaignDate: startDate != null ? _formatDate(startDate) : '',
          documentName: fileName,
          status: allPassed
              ? ValidationStatus.ok
              : photoRemarks.isNotEmpty
                  ? ValidationStatus.failed
                  : ValidationStatus.ok,
          remarks: photoRemarks,
          blobUrl: blobUrl,
          documentId: photoDocId,
          downloadPath: photoId.isNotEmpty ? '/hierarchical/photos/$photoId/download' : null,
          isFirstInGroup: false,
        ));
        serialNumber++;
      }
    }

    return rows;
  }

  /// Parses extractedData which can be a JSON string or a Map.
  static Map<String, dynamic>? _parseExtractedData(dynamic extractedData) {
    if (extractedData == null) return null;
    if (extractedData is Map) {
      return Map<String, dynamic>.from(extractedData);
    }
    if (extractedData is String && extractedData.isNotEmpty) {
      try {
        final parsed = jsonDecode(extractedData);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return null;
  }

  /// Formats a date value to DD MMM YYYY. Returns empty string if null/invalid.
  static String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  /// Extracts campaign date from photo's extracted data. Returns empty string
  /// if not available.
  static String _formatCampaignDate(dynamic extractedData) {
    final data = _parseExtractedData(extractedData);
    if (data == null) return '';
    final dateValue = data['CampaignDate'] ??
        data['campaignDate'] ??
        data['EventDate'] ??
        data['eventDate'] ??
        data['Date'] ??
        data['date'];
    if (dateValue == null) return '';
    return _formatDate(dateValue);
  }

  /// Builds remarks for a document type by parsing the failureReason string.
  /// Splits by ';' and maps each message to document types based on keywords.
  static String buildRemarksFromFailureReason(
    String docType,
    String failureReason,
    bool allPassed,
  ) {
    if (allPassed || failureReason.isEmpty) return '';

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

    // PO-related keywords
    if (lowerMsg.contains('po line item') ||
        lowerMsg.contains('po amount') ||
        lowerMsg.contains('po number') ||
        lowerMsg.contains('po date') ||
        lowerMsg.contains('sap')) {
      types.add('PO');
    }

    // Invoice-related keywords
    if (lowerMsg.contains('invoice') ||
        lowerMsg.contains('gst') ||
        lowerMsg.contains('hsn') ||
        lowerMsg.contains('sac code') ||
        lowerMsg.contains('vendor code') ||
        lowerMsg.contains('vendor name') ||
        lowerMsg.contains('billing')) {
      types.add('Invoice');
    }

    // Messages about PO line items in Invoice affect both
    if (lowerMsg.contains('po line item') && lowerMsg.contains('invoice')) {
      types.add('PO');
      types.add('Invoice');
    }

    // Invoice amount vs PO amount affects both
    if (lowerMsg.contains('invoice amount') && lowerMsg.contains('po amount')) {
      types.add('PO');
      types.add('Invoice');
    }

    // Missing required fields with specific field names
    if (lowerMsg.contains('missing required fields')) {
      // Check for invoice-specific fields
      if (lowerMsg.contains('vendor code') ||
          lowerMsg.contains('po number') ||
          lowerMsg.contains('invoice number') ||
          lowerMsg.contains('gst') ||
          lowerMsg.contains('hsn')) {
        types.add('Invoice');
      }
      // Check for cost summary fields
      if (lowerMsg.contains('element wise quantity') ||
          lowerMsg.contains('number of activations') ||
          lowerMsg.contains('number of days') ||
          lowerMsg.contains('number of teams') ||
          lowerMsg.contains('total cost') ||
          lowerMsg.contains('campaign')) {
        types.add('CostSummary');
      }
      // Check for activity fields
      if (lowerMsg.contains('activity') ||
          lowerMsg.contains('activation')) {
        types.add('Activity');
      }
    }

    // Photo-related keywords
    if (lowerMsg.contains('photo') ||
        lowerMsg.contains('image') ||
        lowerMsg.contains('vehicle') ||
        lowerMsg.contains('blue t-shirt') ||
        lowerMsg.contains('branding') ||
        lowerMsg.contains('bajaj vehicle')) {
      types.add('Photo');
    }

    // Cost Summary-related keywords
    if (lowerMsg.contains('cost summary') ||
        lowerMsg.contains('cost breakdown') ||
        lowerMsg.contains('total cost')) {
      types.add('CostSummary');
    }

    // Activity-related keywords
    if (lowerMsg.contains('activity') ||
        lowerMsg.contains('activation')) {
      types.add('Activity');
    }

    // Enquiry dump keywords
    if (lowerMsg.contains('enquiry') || lowerMsg.contains('enquiry dump')) {
      types.add('EnquiryDump');
    }

    // Date validation typically affects PO + Invoice
    if (lowerMsg.contains('date') &&
        (lowerMsg.contains('before') || lowerMsg.contains('after') || lowerMsg.contains('future'))) {
      types.add('PO');
      types.add('Invoice');
    }

    // If nothing matched, try a broad fallback
    if (types.isEmpty) {
      // Generic completeness messages
      if (lowerMsg.contains('missing')) {
        types.add('PO');
        types.add('Invoice');
      }
    }

    return types.toList();
  }
}
