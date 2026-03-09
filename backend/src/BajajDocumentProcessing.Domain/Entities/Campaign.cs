using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a Campaign/Activity linked to an Invoice.
/// One Invoice can have multiple Campaigns.
/// </summary>
public class Campaign : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the invoice this campaign belongs to
    /// </summary>
    public Guid InvoiceId { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the document package (FAP) for easier querying
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the campaign/activity name
    /// </summary>
    public string? CampaignName { get; set; }
    
    /// <summary>
    /// Gets or sets the campaign start date
    /// </summary>
    public DateTime? StartDate { get; set; }
    
    /// <summary>
    /// Gets or sets the campaign end date
    /// </summary>
    public DateTime? EndDate { get; set; }
    
    /// <summary>
    /// Gets or sets the number of working days for the campaign
    /// </summary>
    public int? WorkingDays { get; set; }
    
    /// <summary>
    /// Gets or sets the dealership/dealer name where the activity took place
    /// </summary>
    public string? DealershipName { get; set; }
    
    /// <summary>
    /// Gets or sets the full address of the dealership
    /// </summary>
    public string? DealershipAddress { get; set; }
    
    /// <summary>
    /// Gets or sets the GPS coordinates of the dealership location
    /// </summary>
    public string? GPSLocation { get; set; }
    
    /// <summary>
    /// Gets or sets the state/region where the campaign took place
    /// </summary>
    public string? State { get; set; }
    
    /// <summary>
    /// Gets or sets the total cost for this campaign
    /// </summary>
    public decimal? TotalCost { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of cost breakdown details
    /// </summary>
    public string? CostBreakdownJson { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of teams/members data for this campaign
    /// </summary>
    public string? TeamsJson { get; set; }
    
    /// <summary>
    /// Gets or sets the original filename of the cost summary document (if uploaded separately)
    /// </summary>
    public string? CostSummaryFileName { get; set; }
    
    /// <summary>
    /// Gets or sets the Azure Blob Storage URL for the cost summary document
    /// </summary>
    public string? CostSummaryBlobUrl { get; set; }
    
    /// <summary>
    /// Gets or sets the JSON representation of extracted cost summary data
    /// </summary>
    public string? CostSummaryExtractedDataJson { get; set; }
    
    /// <summary>
    /// Gets or sets the AI confidence score for cost summary extraction
    /// </summary>
    public double? CostSummaryExtractionConfidence { get; set; }

    // Navigation properties
    
    /// <summary>
    /// Gets or sets the invoice this campaign belongs to
    /// </summary>
    public Invoice Invoice { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the document package (FAP) this campaign belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the collection of photos associated with this campaign
    /// </summary>
    public ICollection<CampaignPhoto> Photos { get; set; } = new List<CampaignPhoto>();
}
