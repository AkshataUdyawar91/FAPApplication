using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a photo linked to a Team (formerly CampaignPhoto).
/// Each Team can have multiple photos with metadata and validation results.
/// </summary>
public class TeamPhotos : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the team this photo belongs to
    /// </summary>
    public Guid TeamId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the document package (FAP) this photo belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the original file name of the photo
    /// </summary>
    public string FileName { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the Azure Blob Storage URL for the photo
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
    /// Gets or sets the optional caption or description for the photo
    /// </summary>
    public string? Caption { get; set; }
    
    /// <summary>
    /// Gets or sets the timestamp when the photo was taken (from EXIF data)
    /// </summary>
    public DateTime? PhotoTimestamp { get; set; }
    
    /// <summary>
    /// Gets or sets the latitude coordinate (from EXIF GPS data)
    /// </summary>
    public double? Latitude { get; set; }
    
    /// <summary>
    /// Gets or sets the longitude coordinate (from EXIF GPS data)
    /// </summary>
    public double? Longitude { get; set; }
    
    /// <summary>
    /// Gets or sets the device model used to capture the photo (from EXIF data)
    /// </summary>
    public string? DeviceModel { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of extracted metadata from the photo
    /// </summary>
    public string? ExtractedMetadataJson { get; set; }
    
    /// <summary>
    /// Gets or sets the confidence score for metadata extraction (0-100)
    /// </summary>
    public double? ExtractionConfidence { get; set; }
    
    /// <summary>
    /// Gets or sets whether this photo is flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }
    
    /// <summary>
    /// Gets or sets the display order for sorting photos within a team
    /// </summary>
    public int DisplayOrder { get; set; }
    
    /// <summary>
    /// Gets or sets the version number for tracking resubmissions
    /// </summary>
    public int VersionNumber { get; set; } = 1;
    
    // Navigation properties
    
    /// <summary>
    /// Gets or sets the team this photo belongs to
    /// </summary>
    public Teams Team { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the document package (FAP) this photo belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the validation result for this photo (one-to-one, nullable)
    /// </summary>
    public ValidationResult? ValidationResult { get; set; }
}
