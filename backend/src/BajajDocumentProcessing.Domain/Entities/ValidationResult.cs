using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Validation result entity for document package validation
/// </summary>
public class ValidationResult : BaseEntity
{
    public Guid PackageId { get; set; }
    public bool SapVerificationPassed { get; set; }
    public bool AmountConsistencyPassed { get; set; }
    public bool LineItemMatchingPassed { get; set; }
    public bool CompletenessCheckPassed { get; set; }
    public bool DateValidationPassed { get; set; }
    public bool VendorMatchingPassed { get; set; }
    public bool AllValidationsPassed { get; set; }
    public string? ValidationDetailsJson { get; set; }
    public string? FailureReason { get; set; }

    // Navigation properties
    public DocumentPackage Package { get; set; } = null!;
}
