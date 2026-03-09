import 'invoice_document_row.dart';

/// Data model for a row in the Campaign Details Table.
/// 
/// Represents a single campaign photo with its dealer information,
/// validation status, and remarks from AI validation. Photos are
/// grouped by dealer (D1, D2, etc.) with sequential naming (Pic1, Pic2).
/// 
/// Requirements: 4.3, 4.4, 4.9
class CampaignDetailRow {
  /// Serial number for display in the table (1-based index).
  final int serialNumber;
  
  /// Dealer name or code (e.g., "D1", "D2").
  final String dealerName;
  
  /// Date of the campaign event.
  final String campaignDate;
  
  /// Name of the document/photo (e.g., "Pic1", "Pic2").
  final String documentName;
  
  /// Validation status indicating if the photo passed or failed validation.
  final ValidationStatus status;
  
  /// AI validation remarks describing the validation result
  /// (e.g., "photo was clear", "photo was not clear").
  final String remarks;
  
  /// Optional blob URL for viewing the photo.
  final String? blobUrl;

  /// Document ID from the API for authenticated download.
  final String? documentId;
  
  /// Indicates if this is the first row in a dealer group.
  final bool isFirstInGroup;

  /// Creates a CampaignDetailRow instance.
  const CampaignDetailRow({
    required this.serialNumber,
    required this.dealerName,
    required this.campaignDate,
    required this.documentName,
    required this.status,
    required this.remarks,
    this.blobUrl,
    this.documentId,
    this.isFirstInGroup = false,
  });

  /// Creates a copy of this row with the given fields replaced.
  CampaignDetailRow copyWith({
    int? serialNumber,
    String? dealerName,
    String? campaignDate,
    String? documentName,
    ValidationStatus? status,
    String? remarks,
    String? blobUrl,
    String? documentId,
    bool? isFirstInGroup,
  }) {
    return CampaignDetailRow(
      serialNumber: serialNumber ?? this.serialNumber,
      dealerName: dealerName ?? this.dealerName,
      campaignDate: campaignDate ?? this.campaignDate,
      documentName: documentName ?? this.documentName,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      blobUrl: blobUrl ?? this.blobUrl,
      documentId: documentId ?? this.documentId,
      isFirstInGroup: isFirstInGroup ?? this.isFirstInGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampaignDetailRow &&
        other.serialNumber == serialNumber &&
        other.dealerName == dealerName &&
        other.campaignDate == campaignDate &&
        other.documentName == documentName &&
        other.status == status &&
        other.remarks == remarks &&
        other.blobUrl == blobUrl &&
        other.documentId == documentId &&
        other.isFirstInGroup == isFirstInGroup;
  }

  @override
  int get hashCode {
    return Object.hash(serialNumber, dealerName, campaignDate, documentName,
        status, remarks, blobUrl, documentId, isFirstInGroup);
  }

  @override
  String toString() {
    return 'CampaignDetailRow(serialNumber: $serialNumber, dealerName: $dealerName, '
        'campaignDate: $campaignDate, documentName: $documentName, status: $status, '
        'remarks: $remarks, blobUrl: $blobUrl, documentId: $documentId, '
        'isFirstInGroup: $isFirstInGroup)';
  }
}
