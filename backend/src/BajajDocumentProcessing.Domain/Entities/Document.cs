using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an uploaded document file (PO, Invoice, Cost Summary, Activity, or Photo) within a submission package
/// </summary>
public class Document : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package this document belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the type of document (PO, Invoice, CostSummary, Activity, Photo)
    /// </summary>
    public DocumentType Type { get; set; }
    
    /// <summary>
    /// Gets or sets the original filename of the uploaded document
    /// </summary>
    public string FileName { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the Azure Blob Storage URL where the document is stored
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the file size in bytes
    /// </summary>
    public long FileSizeBytes { get; set; }
    
    /// <summary>
    /// Gets or sets the MIME content type of the document (e.g., "application/pdf", "image/jpeg")
    /// </summary>
    public string ContentType { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the JSON representation of data extracted from the document by AI
    /// </summary>
    public string? ExtractedDataJson { get; set; }
    
    /// <summary>
    /// Gets or sets the AI confidence score (0-100) for the data extraction quality
    /// </summary>
    public double? ExtractionConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets whether this document is flagged for manual review due to low extraction confidence
    /// </summary>
    public bool IsFlaggedForReview { get; set; }

    /// <summary>
    /// Gets or sets the document package this document belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the collection of invoices linked to this document (only applicable for PO documents)
    /// </summary>
    public ICollection<Invoice> LinkedInvoices { get; set; } = new List<Invoice>();
}
