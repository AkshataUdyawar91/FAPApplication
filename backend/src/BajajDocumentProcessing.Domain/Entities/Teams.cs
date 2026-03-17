using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a Team linked directly to a DocumentPackage (FAP).
/// One PO can have multiple Teams.
/// Each Team can have: multiple Invoices, multiple TeamPhotos.
/// Cost Summary and Activity Summary are now separate entities at the Package level.
/// </summary>
public class Teams : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package (FAP) this team belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Gets or sets the campaign/team name
    /// </summary>
    public string? CampaignName { get; set; }
    
    /// <summary>
    /// Gets or sets the team identifier or code
    /// </summary>
    public string? TeamCode { get; set; }
    
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
    /// Gets or sets the JSON representation of teams/members data for this campaign
    /// </summary>
    public string? TeamsJson { get; set; }

    /// <summary>
    /// Gets or sets the version number for tracking resubmissions
    /// </summary>
    public int VersionNumber { get; set; } = 1;

    // ============ REMOVED FIELDS (now separate entities) ============
    // Cost Summary fields moved to CostSummary entity
    // Activity Summary fields moved to ActivitySummary entity
    
    // Navigation properties
    
    /// <summary>
    /// Gets or sets the document package (FAP) this team belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the collection of photos associated with this team
    /// </summary>
    public ICollection<TeamPhotos> Photos { get; set; } = new List<TeamPhotos>();
}
