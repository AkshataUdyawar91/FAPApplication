using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents the results of automated validation checks performed on a document package.
/// Includes SAP verification, amount consistency, line item matching, completeness, date validation, and vendor matching
/// </summary>
public class ValidationResult : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package this validation result belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets whether the SAP system verification check passed (PO exists in SAP)
    /// </summary>
    public bool SapVerificationPassed { get; set; }
    
    /// <summary>
    /// Gets or sets whether the amount consistency check passed (PO, Invoice, and Cost Summary amounts match)
    /// </summary>
    public bool AmountConsistencyPassed { get; set; }
    
    /// <summary>
    /// Gets or sets whether the line item matching check passed (line items match across documents)
    /// </summary>
    public bool LineItemMatchingPassed { get; set; }
    
    /// <summary>
    /// Gets or sets whether the completeness check passed (all required documents present)
    /// </summary>
    public bool CompletenessCheckPassed { get; set; }
    
    /// <summary>
    /// Gets or sets whether the date validation check passed (dates are logical and within acceptable ranges)
    /// </summary>
    public bool DateValidationPassed { get; set; }
    
    /// <summary>
    /// Gets or sets whether the vendor matching check passed (vendor information consistent across documents)
    /// </summary>
    public bool VendorMatchingPassed { get; set; }
    
    /// <summary>
    /// Gets or sets whether all validation checks passed successfully
    /// </summary>
    public bool AllValidationsPassed { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of detailed validation results for each check
    /// </summary>
    public string? ValidationDetailsJson { get; set; }
    
    /// <summary>
    /// Gets or sets the reason for validation failure, if any checks failed
    /// </summary>
    public string? FailureReason { get; set; }

    /// <summary>
    /// Gets or sets the document package this validation result belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
}
