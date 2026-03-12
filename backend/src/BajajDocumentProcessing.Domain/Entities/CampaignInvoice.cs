using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an Invoice document linked to a Campaign (Team).
/// One Campaign can have multiple Invoices.
/// </summary>
public class CampaignInvoice : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the campaign this invoice belongs to
    /// </summary>
    public Guid CampaignId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the document package (FAP) for easier querying
    /// </summary>
    public Guid PackageId { get; set; }
    
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

    // Navigation properties
    
    /// <summary>
    /// Gets or sets the team this invoice belongs to
    /// </summary>
    public Teams Team { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the document package (FAP) this invoice belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
}
