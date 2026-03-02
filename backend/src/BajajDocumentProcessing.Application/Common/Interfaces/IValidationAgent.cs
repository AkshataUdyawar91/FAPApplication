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
