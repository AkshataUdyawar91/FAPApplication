using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a Photo linked to a Campaign.
/// One Campaign can have multiple Photos.
/// </summary>
public class CampaignPhoto : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the campaign this photo belongs to
    /// </summary>
    public Guid CampaignId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the document package (FAP) for easier querying
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the original filename of the uploaded photo
    /// </summary>
    public string FileName { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the Azure Blob Storage URL where the photo is stored
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the file size in bytes
    /// </summary>
    public long FileSizeBytes { get; set; }
    
    /// <summary>
    /// Gets or sets the MIME content type of the photo
    /// </summary>
    public string ContentType { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the photo caption or description
    /// </summary>
    public string? Caption { get; set; }
    
    /// <summary>
    /// Gets or sets the photo timestamp extracted from EXIF data
    /// </summary>
    public DateTime? PhotoTimestamp { get; set; }
    
    /// <summary>
    /// Gets or sets the GPS latitude from EXIF data
    /// </summary>
    public double? Latitude { get; set; }
    
    /// <summary>
    /// Gets or sets the GPS longitude from EXIF data
    /// </summary>
    public double? Longitude { get; set; }
    
    /// <summary>
    /// Gets or sets the device/camera model from EXIF data
    /// </summary>
    public string? DeviceModel { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of all extracted EXIF metadata
    /// </summary>
    public string? ExtractedMetadataJson { get; set; }
    
    /// <summary>
    /// Gets or sets the AI confidence score for metadata extraction
    /// </summary>
    public double? ExtractionConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets whether this photo is flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }
    
    /// <summary>
    /// Gets or sets the display order of this photo within the campaign
    /// </summary>
    public int DisplayOrder { get; set; }

    // Navigation properties
    
    /// <summary>
    /// Gets or sets the campaign this photo belongs to
    /// </summary>
    public Campaign Campaign { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the document package (FAP) this photo belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
}
