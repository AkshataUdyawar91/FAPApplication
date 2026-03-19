using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Response containing all per-document validation results for a submission.
/// Reads from the ValidationResults table (populated by the workflow pipeline).
/// </summary>
public class SubmissionValidationsResponse
{
    /// <summary>
    /// Submission package ID
    /// </summary>
    [JsonPropertyName("packageId")]
    public Guid PackageId { get; set; }

    /// <summary>
    /// Whether all document validations passed
    /// </summary>
    [JsonPropertyName("allPassed")]
    public bool AllPassed { get; set; }

    /// <summary>
    /// Per-document validation results
    /// </summary>
    [JsonPropertyName("documents")]
    public List<DocumentValidationDto> Documents { get; set; } = new();

    /// <summary>
    /// Flat list of all individual validation checks across all documents
    /// </summary>
    [JsonPropertyName("checks")]
    public List<ValidationCheckDto> Checks { get; set; } = new();
}

/// <summary>
/// Validation result for a single document type within a submission
/// </summary>
public class DocumentValidationDto
{
    /// <summary>
    /// Document type (PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhoto)
    /// </summary>
    [JsonPropertyName("documentType")]
    public string DocumentType { get; set; } = string.Empty;

    /// <summary>
    /// Document entity ID
    /// </summary>
    [JsonPropertyName("documentId")]
    public Guid DocumentId { get; set; }

    /// <summary>
    /// Original filename of the document
    /// </summary>
    [JsonPropertyName("fileName")]
    public string? FileName { get; set; }

    /// <summary>
    /// Whether all validations passed for this document
    /// </summary>
    [JsonPropertyName("allPassed")]
    public bool AllPassed { get; set; }

    /// <summary>
    /// Failure reason summary (null if passed)
    /// </summary>
    [JsonPropertyName("failureReason")]
    public string? FailureReason { get; set; }

    /// <summary>
    /// Field presence validation result (null if not applicable)
    /// </summary>
    [JsonPropertyName("fieldPresence")]
    public FieldPresenceDto? FieldPresence { get; set; }

    /// <summary>
    /// Cross-document validation result (null if not applicable)
    /// </summary>
    [JsonPropertyName("crossDocument")]
    public CrossDocumentDto? CrossDocument { get; set; }

    /// <summary>
    /// Timestamp when validation was performed
    /// </summary>
    [JsonPropertyName("validatedAt")]
    public DateTime ValidatedAt { get; set; }
}

/// <summary>
/// Field presence validation — lists which required fields are present/missing
/// </summary>
public class FieldPresenceDto
{
    /// <summary>
    /// Whether all required fields are present
    /// </summary>
    [JsonPropertyName("allFieldsPresent")]
    public bool AllFieldsPresent { get; set; }

    /// <summary>
    /// List of missing required field names
    /// </summary>
    [JsonPropertyName("missingFields")]
    public List<string> MissingFields { get; set; } = new();
}

/// <summary>
/// Cross-document validation — checks consistency between documents
/// </summary>
public class CrossDocumentDto
{
    /// <summary>
    /// Whether all cross-document checks passed
    /// </summary>
    [JsonPropertyName("allChecksPass")]
    public bool AllChecksPass { get; set; }

    /// <summary>
    /// List of cross-document validation issues
    /// </summary>
    [JsonPropertyName("issues")]
    public List<string> Issues { get; set; } = new();

    /// <summary>
    /// Individual named check results (e.g., "AgencyCodeMatches": true)
    /// </summary>
    [JsonPropertyName("checkResults")]
    public Dictionary<string, bool> CheckResults { get; set; } = new();
}

/// <summary>
/// A single validation check with pass/fail status and description
/// </summary>
public class ValidationCheckDto
{
    /// <summary>
    /// Document type this check belongs to
    /// </summary>
    [JsonPropertyName("documentType")]
    public string DocumentType { get; set; } = string.Empty;

    /// <summary>
    /// Original filename of the document
    /// </summary>
    [JsonPropertyName("fileName")]
    public string? FileName { get; set; }

    /// <summary>
    /// Check category: FieldPresence or CrossDocument
    /// </summary>
    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    /// <summary>
    /// Name of the specific check (e.g., "Invoice Number", "PO Number match with PO")
    /// </summary>
    [JsonPropertyName("checkName")]
    public string CheckName { get; set; } = string.Empty;

    /// <summary>
    /// Whether this check passed
    /// </summary>
    [JsonPropertyName("passed")]
    public bool Passed { get; set; }

    /// <summary>
    /// Human-readable description of the result
    /// </summary>
    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;
}
