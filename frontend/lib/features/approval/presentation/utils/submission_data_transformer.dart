import 'dart:convert';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';
import '../../data/models/invoice_summary_data.dart';

/// Utility class for transforming submission data into table-friendly formats.
/// 
/// Converts raw submission API response data into structured models for
/// the Excel-based ASM Review page layout.
/// 
/// Requirements: 2.2, 2.3, 2.4, 2.5, 3.3, 3.4, 3.5, 4.3, 4.4, 4.5, 4.6
class SubmissionDataTransformer {
  /// Extracts invoice summary data from a submission.
  /// 
  /// Returns [InvoiceSummaryData] with invoice amount, agency name, and
  /// submission date. Returns empty string for any missing fields.
  /// 
  /// Requirements: 2.2, 2.3, 2.4, 2.5
  static InvoiceSummaryData extractInvoiceSummary(
    Map<String, dynamic> submission,
  ) {
    // Extract invoice amount from invoice document
    String invoiceAmount = '';
    final documents = submission['documents'] as List? ?? [];
    
    for (var doc in documents) {
      if (doc['type'] == 'Invoice' && doc['extractedData'] != null) {
        try {
          final extractedData = _parseExtractedData(doc['extractedData']);
          if (extractedData != null) {
            final amount = extractedData['TotalAmount'] ?? 
                          extractedData['totalAmount'];
            if (amount != null) {
              invoiceAmount = '₹$amount';
              break;
            }
          }
        } catch (e) {
          // Keep default empty string
        }
      }
    }
    
    // Extract agency name
    final agencyName = submission['agencyName']?.toString() ?? 
                       submission['agency']?.toString() ?? 
                       '';
    
    // Extract submission date
    final submittedDate = _formatDate(submission['createdAt']);
    
    return InvoiceSummaryData(
      invoiceAmount: invoiceAmount,
      agencyName: agencyName,
      submittedDate: submittedDate,
    );
  }

  /// Transforms documents into invoice document table rows.
  /// 
  /// Converts Invoice, PO, and Cost Summary documents into [InvoiceDocumentRow]
  /// list with validation status and remarks from AI validation.
  /// 
  /// Requirements: 3.3, 3.4, 3.5
  static List<InvoiceDocumentRow> transformToInvoiceDocuments(
    Map<String, dynamic> submission,
  ) {
    final documents = submission['documents'] as List? ?? [];
    final validationResult = submission['validationResult'] as Map<String, dynamic>?;
    final rows = <InvoiceDocumentRow>[];
    int serialNumber = 1;
    
    // Process documents in order: Invoice, PO, Cost Summary
    final docTypes = ['Invoice', 'PO', 'CostSummary'];
    
    for (final docType in docTypes) {
      final doc = documents.firstWhere(
        (d) => d['type'] == docType,
        orElse: () => null,
      );
      
      if (doc != null) {
        final category = _getCategoryName(docType);
        final documentName = doc['filename']?.toString() ?? '$docType.pdf';
        final blobUrl = doc['blobUrl']?.toString();
        
        // Get validation status and remarks
        final validationInfo = _getValidationInfo(docType, validationResult, doc);
        
        rows.add(InvoiceDocumentRow(
          serialNumber: serialNumber++,
          category: category,
          documentName: documentName,
          status: validationInfo.status,
          remarks: validationInfo.remarks,
          blobUrl: blobUrl,
        ));
      }
    }
    
    return rows;
  }

  /// Transforms photos into campaign detail table rows grouped by dealer.
  /// 
  /// Groups photos by dealer (D1, D2, etc.) with sequential naming (Pic1, Pic2).
  /// Sets [isFirstInGroup] to true for the first photo of each dealer.
  /// 
  /// Requirements: 4.3, 4.4, 4.5, 4.6, 4.9
  static List<CampaignDetailRow> transformToCampaignDetails(
    Map<String, dynamic> submission,
  ) {
    final documents = submission['documents'] as List? ?? [];
    final validationResult = submission['validationResult'] as Map<String, dynamic>?;
    final photos = documents.where((d) => d['type'] == 'Photo').toList();
    
    if (photos.isEmpty) {
      return [];
    }
    
    // Extract campaign date from submission
    final campaignDate = _formatCampaignDate(submission['createdAt']);
    
    // Group photos by dealer
    final dealerGroups = <String, List<Map<String, dynamic>>>{};
    
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      // Extract dealer from photo metadata or use default grouping
      final dealer = _extractDealerFromPhoto(photo, i, photos.length);
      
      dealerGroups.putIfAbsent(dealer, () => []);
      dealerGroups[dealer]!.add(photo);
    }
    
    // Build rows with dealer grouping
    final rows = <CampaignDetailRow>[];
    int serialNumber = 1;
    
    final sortedDealers = dealerGroups.keys.toList()..sort();
    
    for (final dealer in sortedDealers) {
      final dealerPhotos = dealerGroups[dealer]!;
      
      for (var i = 0; i < dealerPhotos.length; i++) {
        final photo = dealerPhotos[i];
        final picNumber = i + 1;
        final documentName = 'Pic$picNumber';
        final blobUrl = photo['blobUrl']?.toString();
        
        // Get validation status and remarks for photo
        final validationInfo = _getPhotoValidationInfo(
          photo, 
          validationResult,
          serialNumber - 1,
        );
        
        rows.add(CampaignDetailRow(
          serialNumber: serialNumber++,
          dealerName: dealer,
          campaignDate: campaignDate,
          documentName: documentName,
          status: validationInfo.status,
          remarks: validationInfo.remarks,
          blobUrl: blobUrl,
          isFirstInGroup: i == 0,
        ));
      }
    }
    
    return rows;
  }

  // Helper methods
  
  /// Parses extracted data from document (handles both String and Map).
  static Map<String, dynamic>? _parseExtractedData(dynamic extractedData) {
    if (extractedData == null) return null;
    
    if (extractedData is String && extractedData.isNotEmpty) {
      try {
        return jsonDecode(extractedData) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    } else if (extractedData is Map) {
      return Map<String, dynamic>.from(extractedData);
    }
    
    return null;
  }
  
  /// Formats a date string for display.
  static String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return '';
    }
  }
  
  /// Formats campaign date (DD MMM YYYY format).
  static String _formatCampaignDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return '';
    }
  }
  
  /// Gets display category name for document type.
  static String _getCategoryName(String docType) {
    switch (docType) {
      case 'Invoice':
        return 'Invoice';
      case 'PO':
        return 'Purchase Order';
      case 'CostSummary':
        return 'Cost Summary';
      default:
        return docType;
    }
  }
  
  /// Extracts dealer identifier from photo metadata or assigns based on index.
  static String _extractDealerFromPhoto(
    Map<String, dynamic> photo, 
    int index, 
    int totalPhotos,
  ) {
    // Check if dealer info is in photo metadata
    final metadata = photo['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['dealer'] != null) {
      return metadata['dealer'].toString();
    }
    
    // Check extractedData for dealer info
    final extractedData = _parseExtractedData(photo['extractedData']);
    if (extractedData != null && extractedData['dealer'] != null) {
      return extractedData['dealer'].toString();
    }
    
    // Default: return empty string if dealer data not available
    return '';
  }
  
  /// Gets validation info for a document.
  static _ValidationInfo _getValidationInfo(
    String docType,
    Map<String, dynamic>? validationResult,
    Map<String, dynamic> doc,
  ) {
    // Check document-level validation
    if (validationResult != null) {
      final docValidations = validationResult['documentValidations'] as List?;
      if (docValidations != null) {
        for (var validation in docValidations) {
          if (validation['documentType'] == docType) {
            final isValid = validation['isValid'] == true;
            final message = validation['message']?.toString() ?? '';
            return _ValidationInfo(
              status: isValid ? ValidationStatus.ok : ValidationStatus.failed,
              remarks: message,
            );
          }
        }
      }
      
      // Check overall validation
      final allPassed = validationResult['allValidationsPassed'] == true;
      if (allPassed) {
        return _ValidationInfo(
          status: ValidationStatus.ok,
          remarks: '',
        );
      }
    }
    
    // Default: return unknown status if validation data not available
    return _ValidationInfo(
      status: ValidationStatus.unknown,
      remarks: '',
    );
  }
  
  /// Gets validation info for a photo.
  static _ValidationInfo _getPhotoValidationInfo(
    Map<String, dynamic> photo,
    Map<String, dynamic>? validationResult,
    int photoIndex,
  ) {
    // Check photo-specific validation in validationResult
    if (validationResult != null) {
      final photoValidations = validationResult['photoValidations'] as List?;
      if (photoValidations != null && photoIndex < photoValidations.length) {
        final validation = photoValidations[photoIndex];
        final isValid = validation['isValid'] == true;
        final message = validation['message']?.toString() ?? '';
        return _ValidationInfo(
          status: isValid ? ValidationStatus.ok : ValidationStatus.failed,
          remarks: message,
        );
      }
    }
    
    // Check photo extractedData for quality info
    final extractedData = _parseExtractedData(photo['extractedData']);
    if (extractedData != null) {
      final quality = extractedData['quality']?.toString().toLowerCase();
      if (quality == 'poor' || quality == 'low' || quality == 'failed') {
        return _ValidationInfo(
          status: ValidationStatus.failed,
          remarks: '',
        );
      }
    }
    
    // Default: return unknown status if validation data not available
    return _ValidationInfo(
      status: ValidationStatus.unknown,
      remarks: '',
    );
  }
}

/// Internal class to hold validation status and remarks.
class _ValidationInfo {
  final ValidationStatus status;
  final String remarks;
  
  const _ValidationInfo({
    required this.status,
    required this.remarks,
  });
}
