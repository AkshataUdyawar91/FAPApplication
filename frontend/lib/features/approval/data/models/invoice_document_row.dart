/// Enum representing the validation status of a document.
/// 
/// Used in the Invoice Documents Table and Campaign Details Table
/// to indicate whether a document passed or failed validation.
enum ValidationStatus {
  /// Document passed validation
  ok,
  
  /// Document failed validation
  failed,
  
  /// Validation status unknown (no validation data from API)
  unknown,
}

/// Extension to provide display text for ValidationStatus.
extension ValidationStatusExtension on ValidationStatus {
  /// Returns the display string for the status.
  String get displayText {
    switch (this) {
      case ValidationStatus.ok:
        return 'Validated';
      case ValidationStatus.failed:
        return 'Failed';
      case ValidationStatus.unknown:
        return '';
    }
  }
  
  /// Creates a ValidationStatus from a boolean validation result.
  static ValidationStatus fromBool(bool isValid) {
    return isValid ? ValidationStatus.ok : ValidationStatus.failed;
  }
}

/// Data model for a row in the Invoice Documents Table.
/// 
/// Represents a single document (Invoice, PO, or Cost Summary) with its
/// validation status and remarks from AI validation.
/// 
/// Requirements: 3.3, 3.4
class InvoiceDocumentRow {
  /// Serial number for display in the table (1-based index).
  final int serialNumber;
  
  /// Category of the document (e.g., "Invoice", "PO", "Cost Summary").
  final String category;
  
  /// Name of the document file.
  final String documentName;
  
  /// Validation status indicating if the document passed or failed validation.
  final ValidationStatus status;
  
  /// AI validation remarks describing the validation result.
  final String remarks;
  
  /// Optional blob URL for viewing or downloading the document.
  final String? blobUrl;

  /// Document ID from the API for authenticated download.
  final String? documentId;

  /// Creates an InvoiceDocumentRow instance.
  const InvoiceDocumentRow({
    required this.serialNumber,
    required this.category,
    required this.documentName,
    required this.status,
    required this.remarks,
    this.blobUrl,
    this.documentId,
  });

  /// Creates a copy of this row with the given fields replaced.
  InvoiceDocumentRow copyWith({
    int? serialNumber,
    String? category,
    String? documentName,
    ValidationStatus? status,
    String? remarks,
    String? blobUrl,
    String? documentId,
  }) {
    return InvoiceDocumentRow(
      serialNumber: serialNumber ?? this.serialNumber,
      category: category ?? this.category,
      documentName: documentName ?? this.documentName,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      blobUrl: blobUrl ?? this.blobUrl,
      documentId: documentId ?? this.documentId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvoiceDocumentRow &&
        other.serialNumber == serialNumber &&
        other.category == category &&
        other.documentName == documentName &&
        other.status == status &&
        other.remarks == remarks &&
        other.blobUrl == blobUrl &&
        other.documentId == documentId;
  }

  @override
  int get hashCode {
    return Object.hash(serialNumber, category, documentName, status, remarks, blobUrl, documentId);
  }

  @override
  String toString() {
    return 'InvoiceDocumentRow(serialNumber: $serialNumber, category: $category, '
        'documentName: $documentName, status: $status, remarks: $remarks, '
        'blobUrl: $blobUrl, documentId: $documentId)';
  }
}
