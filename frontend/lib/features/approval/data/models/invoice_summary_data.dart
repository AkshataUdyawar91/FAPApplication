/// Data model for the Invoice Summary section.
/// 
/// Contains the key summary information displayed at the top of the
/// ASM Review page: invoice amount, agency name, and submission date.
/// 
/// Requirements: 2.2, 2.3, 2.4, 2.5
class InvoiceSummaryData {
  /// The invoice amount extracted from the invoice document.
  /// Displays empty string if not available.
  final String invoiceAmount;
  
  /// The name of the agency that submitted the documents.
  /// Displays empty string if not available.
  final String agencyName;
  
  /// The date when the submission was made.
  /// Displays empty string if not available.
  final String submittedDate;

  /// Creates an InvoiceSummaryData instance.
  const InvoiceSummaryData({
    required this.invoiceAmount,
    required this.agencyName,
    required this.submittedDate,
  });

  /// Creates an empty InvoiceSummaryData with empty string values.
  /// Used when data is missing or unavailable.
  factory InvoiceSummaryData.empty() {
    return const InvoiceSummaryData(
      invoiceAmount: '',
      agencyName: '',
      submittedDate: '',
    );
  }

  /// Creates a copy of this data with the given fields replaced.
  InvoiceSummaryData copyWith({
    String? invoiceAmount,
    String? agencyName,
    String? submittedDate,
  }) {
    return InvoiceSummaryData(
      invoiceAmount: invoiceAmount ?? this.invoiceAmount,
      agencyName: agencyName ?? this.agencyName,
      submittedDate: submittedDate ?? this.submittedDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvoiceSummaryData &&
        other.invoiceAmount == invoiceAmount &&
        other.agencyName == agencyName &&
        other.submittedDate == submittedDate;
  }

  @override
  int get hashCode {
    return Object.hash(invoiceAmount, agencyName, submittedDate);
  }

  @override
  String toString() {
    return 'InvoiceSummaryData('
        'invoiceAmount: $invoiceAmount, '
        'agencyName: $agencyName, '
        'submittedDate: $submittedDate)';
  }
}
