using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// DTO representing document information from any dedicated document table.
/// Replaces the legacy Document entity as the return type for document retrieval.
/// </summary>
public class DocumentInfoDto
{
    /// <summary>
    /// Unique identifier of the document
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// Identifier of the parent package
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Type of document (PO, Invoice, CostSummary, etc.)
    /// </summary>
    public DocumentType Type { get; set; }

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
    /// MIME content type
    /// </summary>
    public string ContentType { get; set; } = string.Empty;

    /// <summary>
    /// JSON string of extracted data from AI processing
    /// </summary>
    public string? ExtractedDataJson { get; set; }

    /// <summary>
    /// Confidence score from AI extraction (0.0 to 100.0)
    /// </summary>
    public double? ExtractionConfidence { get; set; }

    /// <summary>
    /// Whether this document has been flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }
}
