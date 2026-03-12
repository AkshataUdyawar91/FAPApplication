using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Purchase Order document entity (one per package).
/// Represents the primary PO document in a submission package.
/// </summary>
public class PO : BaseEntity
{
    /// <summary>
    /// Foreign key to the parent DocumentPackage (one-to-one relationship).
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Foreign key to the Agency that submitted this PO.
    /// </summary>
    public Guid AgencyId { get; set; }

    /// <summary>
    /// Extracted PO number from the document.
    /// </summary>
    public string? PONumber { get; set; }

    /// <summary>
    /// Extracted PO date from the document.
    /// </summary>
    public DateTime? PODate { get; set; }

    /// <summary>
    /// Extracted vendor name from the document.
    /// </summary>
    public string? VendorName { get; set; }

    /// <summary>
    /// Extracted total amount from the document.
    /// </summary>
    public decimal? TotalAmount { get; set; }

    /// <summary>
    /// Original file name of the uploaded PO document.
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Azure Blob Storage URL for the PO document.
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
    /// Navigation property to the Agency.
    /// </summary>
    public Agency Agency { get; set; } = null!;

    /// <summary>
    /// Navigation property to the ValidationResult for this PO.
    /// </summary>
    public ValidationResult? ValidationResult { get; set; }
}
