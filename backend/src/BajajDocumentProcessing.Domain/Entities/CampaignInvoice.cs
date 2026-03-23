using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an invoice associated with a campaign (Team).
/// </summary>
public class CampaignInvoice : BaseEntity
{
    /// <summary>FK to the parent Team (campaign)</summary>
    public Guid CampaignId { get; set; }

    /// <summary>FK to the parent DocumentPackage</summary>
    public Guid PackageId { get; set; }

    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public string? VendorName { get; set; }
    public string? GSTNumber { get; set; }
    public decimal? SubTotal { get; set; }
    public decimal? TaxAmount { get; set; }
    public decimal? TotalAmount { get; set; }

    /// <summary>Original uploaded file name</summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>Azure Blob Storage URL</summary>
    public string BlobUrl { get; set; } = string.Empty;

    public long FileSizeBytes { get; set; }
    public string ContentType { get; set; } = string.Empty;

    /// <summary>JSON blob of AI-extracted data</summary>
    public string? ExtractedDataJson { get; set; }

    public double? ExtractionConfidence { get; set; }
    public bool IsFlaggedForReview { get; set; }

    // ── Navigation Properties ──
    public Teams Team { get; set; } = null!;
    public DocumentPackage Package { get; set; } = null!;
}
