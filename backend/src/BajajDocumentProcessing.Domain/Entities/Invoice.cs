using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an Invoice document linked to a PO within a FAP submission.
/// One PO can have multiple Invoices.
/// </summary>
public class Invoice : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package (FAP) this invoice belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the PO this invoice is linked to
    /// </summary>
    public Guid POId { get; set; }
    
    /// <summary>
    /// Gets or sets the version number for tracking resubmissions (matches parent package version)
    /// </summary>
    public int VersionNumber { get; set; } = 1;
    
    // ============ DEPRECATED FIELD - TO BE REMOVED IN FUTURE MIGRATION ============
    
    // /// <summary>
    // /// DEPRECATED: Gets or sets the unique identifier of the PO document this invoice is linked to (replaced by POId)
    // /// </summary>
    // public Guid PODocumentId { get; set; }
    
    /// <summary>
    /// Gets or sets the invoice number extracted from the document
    /// </summary>
    public string? InvoiceNumber { get; set; }
    
    /// <summary>
    /// Gets or sets the invoice date
    /// </summary>
    public DateTime? InvoiceDate { get; set; }
    
    /// <summary>
    /// Gets or sets the vendor/supplier name on the invoice
    /// </summary>
    public string? VendorName { get; set; }
    
    /// <summary>
    /// Gets or sets the GST number on the invoice
    /// </summary>
    public string? GSTNumber { get; set; }
    
    /// <summary>
    /// Gets or sets the subtotal amount before tax
    /// </summary>
    public decimal? SubTotal { get; set; }
    
    /// <summary>
    /// Gets or sets the tax amount
    /// </summary>
    public decimal? TaxAmount { get; set; }
    
    /// <summary>
    /// Gets or sets the total invoice amount
    /// </summary>
    public decimal? TotalAmount { get; set; }
    
    /// <summary>
    /// Gets or sets the original filename of the uploaded invoice document
    /// </summary>
    public string FileName { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the Azure Blob Storage URL where the invoice document is stored
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the file size in bytes
    /// </summary>
    public long FileSizeBytes { get; set; }
    
    /// <summary>
    /// Gets or sets the MIME content type of the document
    /// </summary>
    public string ContentType { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the JSON representation of all extracted data from the invoice
    /// </summary>
    public string? ExtractedDataJson { get; set; }
    
    /// <summary>
    /// Gets or sets the AI confidence score (0-100) for the data extraction quality
    /// </summary>
    public double? ExtractionConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets whether this invoice is flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }

    // ============ NAVIGATION PROPERTIES ============
    
    /// <summary>
    /// Gets or sets the document package (FAP) this invoice belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the PO this invoice is linked to
    /// </summary>
    public PO PO { get; set; } = null!;
    
    // DEPRECATED NAVIGATION PROPERTY - TO BE REMOVED
    // /// <summary>
    // /// DEPRECATED: Gets or sets the PO document this invoice is linked to (replaced by PO navigation property)
    // /// </summary>
    // public Document PODocument { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the validation result for this invoice (one-to-one relationship)
    /// </summary>
    public ValidationResult? ValidationResult { get; set; }
    
}
