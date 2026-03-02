using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Document entity representing an uploaded file
/// </summary>
public class Document : BaseEntity
{
    public Guid PackageId { get; set; }
    public DocumentType Type { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string BlobUrl { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public string ContentType { get; set; } = string.Empty;
    public string? ExtractedDataJson { get; set; }
    public double? ExtractionConfidence { get; set; }
    public bool IsFlaggedForReview { get; set; }

    // Navigation properties
    public DocumentPackage Package { get; set; } = null!;
}
