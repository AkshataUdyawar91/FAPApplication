using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Cost summary document entity (one per package).
/// Represents the cost breakdown document in a submission package.
/// </summary>
public class CostSummary : BaseEntity
{
    /// <summary>
    /// Foreign key to the parent DocumentPackage (one-to-one relationship).
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Extracted total cost from the document.
    /// </summary>
    public decimal? TotalCost { get; set; }

    /// <summary>
    /// Detailed cost breakdown in JSON format.
    /// Contains line items, categories, and subcategories.
    /// </summary>
    public string? CostBreakdownJson { get; set; }

    /// <summary>
    /// Original file name of the uploaded cost summary document.
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Azure Blob Storage URL for the cost summary document.
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;

    /// <summary>
    /// File size in bytes.
    /// </summary>
    public long FileSizeBytes { get; set; }

    /// <summary>
    /// MIME content type of the file.
    /// </summary>
    public string ContentType { get; set; } = string.Empty;

    /// <summary>
    /// Full extracted data in JSON format from Azure OpenAI.
    /// </summary>
    public string? ExtractedDataJson { get; set; }

    /// <summary>
    /// Confidence score of the extraction (0.0 to 1.0).
    /// </summary>
    public double? ExtractionConfidence { get; set; }

    /// <summary>
    /// Indicates if this document has been flagged for manual review.
    /// </summary>
    public bool IsFlaggedForReview { get; set; }

    /// <summary>
    /// Version number matching the parent package version.
    /// Increments on resubmission.
    /// </summary>
    public int VersionNumber { get; set; } = 1;

    // Navigation Properties

    /// <summary>
    /// Navigation property to the parent DocumentPackage.
    /// </summary>
    public DocumentPackage DocumentPackage { get; set; } = null!;

    /// <summary>
    /// Navigation property to the ValidationResult for this cost summary.
    /// </summary>
    public ValidationResult? ValidationResult { get; set; }
}
