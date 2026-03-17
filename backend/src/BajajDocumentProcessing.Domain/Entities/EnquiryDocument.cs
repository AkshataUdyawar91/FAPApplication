using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an enquiry document associated with a document package.
/// One-to-one relationship with DocumentPackage.
/// </summary>
public class EnquiryDocument : BaseEntity
{
    /// <summary>
    /// Foreign key to the parent DocumentPackage (one-to-one relationship)
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Original file name
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Azure Blob Storage URL
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;

    /// <summary>
    /// File size in bytes
    /// </summary>
    public long FileSizeBytes { get; set; }

    /// <summary>
    /// MIME content type (e.g., application/pdf, image/jpeg)
    /// </summary>
    public string ContentType { get; set; } = string.Empty;

    /// <summary>
    /// JSON string containing extracted data from the document
    /// </summary>
    public string? ExtractedDataJson { get; set; }

    /// <summary>
    /// AI confidence score for data extraction (0.0 to 1.0)
    /// </summary>
    public double? ExtractionConfidence { get; set; }

    /// <summary>
    /// Indicates if this document requires manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }

    /// <summary>
    /// Version number matching the parent package version
    /// Increments on resubmission
    /// </summary>
    public int VersionNumber { get; set; } = 1;

    // Navigation Properties

    /// <summary>
    /// Parent document package (one-to-one)
    /// </summary>
    public DocumentPackage DocumentPackage { get; set; } = null!;

    /// <summary>
    /// Validation result for this enquiry document (one-to-one)
    /// </summary>
    public ValidationResult? ValidationResult { get; set; }
}
