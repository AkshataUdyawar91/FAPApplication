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
  /// Shows ALL non-Photo documents from the API response. Each document
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
      // Skip Photo-type documents — those go in Campaign Details
      if (type == 'Photo') continue;

      final filename = doc['filename']?.toString() ?? '';
      final blobUrl = doc['blobUrl']?.toString() ?? '';
      final docId = doc['id']?.toString() ?? '';
      final validationInfo = _getValidationInfo(type, failureReason, allPassed);

      rows.add(InvoiceDocumentRow(
        serialNumber: serialNumber,
        category: type,
        documentName: filename,
        status: validationInfo.status,
        remarks: validationInfo.remarks,
        blobUrl: blobUrl,
        documentId: docId,
      ));
      serialNumber++;
    }

    return rows;
  }

  /// Transforms submission documents into campaign detail rows.
  ///
  /// Shows ALL Photo-type documents from the API response. Uses actual
  /// filenames from the API (not generated names like Pic1/Pic2).
  static List<CampaignDetailRow> transformToCampaignDetails(
    Map<String, dynamic> submission,
  ) {
    final documents = submission['documents'] as List? ?? [];
    final failureReason =
        submission['validationResult']?['failureReason']?.toString() ?? '';
    final allPassed =
        submission['validationResult']?['allValidationsPassed'] == true;

    final rows = <CampaignDetailRow>[];
    int serialNumber = 1;

    for (var doc in documents) {
      final type = doc['type']?.toString() ?? '';
      if (type != 'Photo') continue;

      final filename = doc['filename']?.toString() ?? '';
      final blobUrl = doc['blobUrl']?.toString() ?? '';
      final docId = doc['id']?.toString() ?? '';
      final campaignDate = _formatCampaignDate(doc['extractedData']);
      final validationInfo =
          _getPhotoValidationInfo(failureReason, allPassed);

      rows.add(CampaignDetailRow(
        serialNumber: serialNumber,
        dealerName: '',
        campaignDate: campaignDate,
        documentName: filename,
        status: validationInfo.status,
        remarks: validationInfo.remarks,
        blobUrl: blobUrl,
        documentId: docId,
        isFirstInGroup: serialNumber == 1,
      ));
      serialNumber++;
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

  /// Gets validation info for a specific document type from the failureReason
  /// string. Remarks are left empty — AI analysis is shown in the dedicated
  /// collapsible AI Analysis section instead.
  static _ValidationInfo _getValidationInfo(
    String docType,
    String failureReason,
    bool allPassed,
  ) {
    if (allPassed) {
      return const _ValidationInfo(ValidationStatus.ok, '');
    }
    if (failureReason.isEmpty) {
      return const _ValidationInfo(ValidationStatus.unknown, '');
    }

    final lowerReason = failureReason.toLowerCase();
    final lowerType = docType.toLowerCase();

    if (lowerReason.contains(lowerType)) {
      return const _ValidationInfo(ValidationStatus.failed, '');
    }

    return const _ValidationInfo(ValidationStatus.ok, '');
  }

  /// Gets validation info for photo documents from the failureReason string.
  /// Remarks are left empty — AI analysis is shown in the collapsible section.
  static _ValidationInfo _getPhotoValidationInfo(
    String failureReason,
    bool allPassed,
  ) {
    if (allPassed) {
      return const _ValidationInfo(ValidationStatus.ok, '');
    }
    if (failureReason.isEmpty) {
      return const _ValidationInfo(ValidationStatus.unknown, '');
    }

    final lowerReason = failureReason.toLowerCase();
    if (lowerReason.contains('photo') || lowerReason.contains('image')) {
      return const _ValidationInfo(ValidationStatus.failed, '');
    }

    return const _ValidationInfo(ValidationStatus.ok, '');
  }
}

/// Internal helper class for validation info.
class _ValidationInfo {
  final ValidationStatus status;
  final String remarks;

  const _ValidationInfo(this.status, this.remarks);
}
