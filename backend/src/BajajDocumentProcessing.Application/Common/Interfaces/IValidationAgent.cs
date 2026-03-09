using BajajDocumentProcessing.Application.DTOs.Documents;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Validation Agent interface for cross-document validation and SAP verification
/// </summary>
public interface IValidationAgent
{
    /// <summary>
    /// Validates a complete document package
    /// </summary>
    /// <param name="packageId">ID of the document package to validate</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Validation result with all validation checks</returns>
    Task<PackageValidationResult> ValidatePackageAsync(Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Verifies PO data against SAP system
    /// </summary>
    /// <param name="poNumber">PO number to verify</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>SAP verification result</returns>
    Task<SAPVerificationResult> VerifySAPPOAsync(string poNumber, CancellationToken cancellationToken = default);

    /// <summary>
    /// Validates amount consistency between Invoice and Cost Summary
    /// </summary>
    /// <param name="invoiceTotal">Total amount from Invoice</param>
    /// <param name="costSummaryTotal">Total amount from Cost Summary</param>
    /// <returns>True if amounts are consistent within tolerance (±2%)</returns>
    bool ValidateAmountConsistency(decimal invoiceTotal, decimal costSummaryTotal);

    /// <summary>
    /// Validates that all PO line items appear in Invoice
    /// </summary>
    /// <param name="poItems">Line items from PO</param>
    /// <param name="invoiceItems">Line items from Invoice</param>
    /// <returns>True if all PO items are present in Invoice</returns>
    bool ValidateLineItems(List<POLineItem> poItems, List<InvoiceLineItem> invoiceItems);

    /// <summary>
    /// Validates completeness of document package (11 required items)
    /// </summary>
    /// <param name="packageId">ID of the document package</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Completeness validation result</returns>
    Task<CompletenessResult> ValidateCompletenessAsync(Guid packageId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Result of package validation
/// </summary>
public class PackageValidationResult
{
    public Guid PackageId { get; set; }
    public bool AllPassed { get; set; }
    public SAPVerificationResult? SAPVerification { get; set; }
    public AmountConsistencyResult? AmountConsistency { get; set; }
    public LineItemMatchingResult? LineItemMatching { get; set; }
    public CompletenessResult? Completeness { get; set; }
    public DateValidationResult? DateValidation { get; set; }
    public VendorMatchingResult? VendorMatching { get; set; }
    public InvoiceFieldPresenceResult? InvoiceFieldPresence { get; set; }
    public InvoiceCrossDocumentResult? InvoiceCrossDocument { get; set; }
    public CostSummaryFieldPresenceResult? CostSummaryFieldPresence { get; set; }
    public CostSummaryCrossDocumentResult? CostSummaryCrossDocument { get; set; }
    public ActivityFieldPresenceResult? ActivityFieldPresence { get; set; }
    public ActivityCrossDocumentResult? ActivityCrossDocument { get; set; }
    public PhotoFieldPresenceResult? PhotoFieldPresence { get; set; }
    public PhotoCrossDocumentResult? PhotoCrossDocument { get; set; }
    // CHANGE: Added EnquiryDump validation result properties
    public EnquiryDumpFieldPresenceResult? EnquiryDumpFieldPresence { get; set; }
    public EnquiryDumpCrossDocumentResult? EnquiryDumpCrossDocument { get; set; }
    public List<ValidationIssue> Issues { get; set; } = new();
    public DateTime ValidatedAt { get; set; }
}

/// <summary>
/// SAP verification result
/// </summary>
public class SAPVerificationResult
{
    public bool IsVerified { get; set; }
    public bool SAPConnectionFailed { get; set; }
    public string? PONumber { get; set; }
    public string? VendorFromSAP { get; set; }
    public decimal? AmountFromSAP { get; set; }
    public DateTime? DateFromSAP { get; set; }
    public List<string> Discrepancies { get; set; } = new();
}

/// <summary>
/// Amount consistency validation result
/// </summary>
public class AmountConsistencyResult
{
    public bool IsConsistent { get; set; }
    public decimal InvoiceTotal { get; set; }
    public decimal CostSummaryTotal { get; set; }
    public decimal Difference { get; set; }
    public decimal PercentageDifference { get; set; }
    public decimal TolerancePercentage { get; set; } = 2.0m;
}

/// <summary>
/// Line item matching validation result
/// </summary>
public class LineItemMatchingResult
{
    public bool AllItemsMatched { get; set; }
    public List<string> MissingItemCodes { get; set; } = new();
    public int POItemCount { get; set; }
    public int InvoiceItemCount { get; set; }
    public int MatchedItemCount { get; set; }
}

/// <summary>
/// Completeness validation result
/// </summary>
public class CompletenessResult
{
    public bool IsComplete { get; set; }
    public int RequiredItemCount { get; set; } = 11;
    public int PresentItemCount { get; set; }
    public List<string> MissingItems { get; set; } = new();
}

/// <summary>
/// Date validation result
/// </summary>
public class DateValidationResult
{
    public bool IsValid { get; set; }
    public DateTime? PODate { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public DateTime? SubmissionDate { get; set; }
    public List<string> DateIssues { get; set; } = new();
}

/// <summary>
/// Vendor matching validation result
/// </summary>
public class VendorMatchingResult
{
    public bool IsMatched { get; set; }
    public string? POVendor { get; set; }
    public string? InvoiceVendor { get; set; }
    public string? SAPVendor { get; set; }
}

/// <summary>
/// Validation issue details
/// </summary>
public class ValidationIssue
{
    public string Field { get; set; } = string.Empty;
    public string Issue { get; set; } = string.Empty;
    public string? ExpectedValue { get; set; }
    public string? ActualValue { get; set; }
    public string Severity { get; set; } = "Error"; // Error, Warning
}

/// <summary>
/// Invoice field presence validation result
/// </summary>
public class InvoiceFieldPresenceResult
{
    public bool AllFieldsPresent { get; set; }
    public List<string> MissingFields { get; set; } = new();
}

/// <summary>
/// Invoice cross-document validation result
/// </summary>
public class InvoiceCrossDocumentResult
{
    public bool AllChecksPass { get; set; }
    public bool AgencyCodeMatches { get; set; }
    public bool PONumberMatches { get; set; }
    public bool GSTStateMatches { get; set; }
    public bool HSNSACCodeValid { get; set; }
    public bool InvoiceAmountValid { get; set; }
    public bool GSTPercentageValid { get; set; }
    public List<string> Issues { get; set; } = new();
}

/// <summary>
/// Cost Summary field presence validation result
/// </summary>
public class CostSummaryFieldPresenceResult
{
    public bool AllFieldsPresent { get; set; }
    public List<string> MissingFields { get; set; } = new();
}

/// <summary>
/// Cost Summary cross-document validation result
/// </summary>
public class CostSummaryCrossDocumentResult
{
    public bool AllChecksPass { get; set; }
    public bool TotalCostValid { get; set; }
    public bool ElementCostsValid { get; set; }
    public bool FixedCostsValid { get; set; }
    public bool VariableCostsValid { get; set; }
    public List<string> Issues { get; set; } = new();
}

/// <summary>
/// Activity Summary field presence validation result
/// </summary>
public class ActivityFieldPresenceResult
{
    public bool AllFieldsPresent { get; set; }
    public List<string> MissingFields { get; set; } = new();
}

/// <summary>
/// Activity Summary cross-document validation result
/// </summary>
public class ActivityCrossDocumentResult
{
    public bool AllChecksPass { get; set; }
    public bool NumberOfDaysMatches { get; set; }
    public List<string> Issues { get; set; } = new();
}

/// <summary>
/// Photo Proofs field presence validation result
/// </summary>
public class PhotoFieldPresenceResult
{
    public bool AllFieldsPresent { get; set; }
    public int TotalPhotos { get; set; }
    public int PhotosWithDate { get; set; }
    public int PhotosWithLocation { get; set; }
    public int PhotosWithBlueTshirt { get; set; }
    public int PhotosWithVehicle { get; set; }
    public List<string> MissingFields { get; set; } = new();
}

/// <summary>
/// Photo Proofs cross-document validation result
/// </summary>
public class PhotoCrossDocumentResult
{
    public bool AllChecksPass { get; set; }
    public bool PhotoCountMatchesManDays { get; set; }
    public bool ManDaysWithinCostSummaryDays { get; set; }
    public int PhotoCount { get; set; }
    public int ManDays { get; set; }
    public int CostSummaryDays { get; set; }
    public List<string> Issues { get; set; } = new();
}

// CHANGE: Added EnquiryDumpFieldPresenceResult for Enquiry Dump field validation
/// <summary>
/// Enquiry Dump field presence validation result
/// </summary>
public class EnquiryDumpFieldPresenceResult
{
    public bool AllFieldsPresent { get; set; }
    public int TotalRecords { get; set; }
    public int RecordsWithState { get; set; }
    public int RecordsWithDate { get; set; }
    public int RecordsWithDealerCode { get; set; }
    public int RecordsWithDealerName { get; set; }
    public int RecordsWithDistrict { get; set; }
    public int RecordsWithPincode { get; set; }
    public int RecordsWithCustomerName { get; set; }
    public int RecordsWithCustomerNumber { get; set; }
    public int RecordsWithTestRide { get; set; }
    public List<string> MissingFields { get; set; } = new();
}

// CHANGE: Added EnquiryDumpCrossDocumentResult for cross-document validation
/// <summary>
/// Enquiry Dump cross-document validation result
/// </summary>
public class EnquiryDumpCrossDocumentResult
{
    public bool AllChecksPass { get; set; }
    public bool StateMatchesActivity { get; set; }
    public bool DealerDetailsMatchActivity { get; set; }
    public List<string> Issues { get; set; } = new();
}
