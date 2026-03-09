namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Activity Summary (Enquiry & Docs) extracted data
/// </summary>
public class ActivityData
{
    /// <summary>
    /// Dealer name from the activity document
    /// </summary>
    public string? DealerName { get; set; }
    
    /// <summary>
    /// Dealer code identifier
    /// </summary>
    public string? DealerCode { get; set; }
    
    /// <summary>
    /// Dealer address
    /// </summary>
    public string? DealerAddress { get; set; }
    
    /// <summary>
    /// List of activities at different locations
    /// </summary>
    public List<LocationActivity> LocationActivities { get; set; } = new();
    
    /// <summary>
    /// Total number of days across all activities
    /// </summary>
    public int? TotalDays { get; set; }
    
    /// <summary>
    /// AI confidence scores for each extracted field (0-100)
    /// </summary>
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    
    /// <summary>
    /// Whether this document has been flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Activity at a specific location
/// </summary>
public class LocationActivity
{
    /// <summary>
    /// Name of the location where activity took place
    /// </summary>
    public string LocationName { get; set; } = string.Empty;
    
    /// <summary>
    /// Address of the location
    /// </summary>
    public string? LocationAddress { get; set; }
    
    /// <summary>
    /// City where the activity took place
    /// </summary>
    public string? City { get; set; }
    
    /// <summary>
    /// State where the activity took place
    /// </summary>
    public string? State { get; set; }
    
    /// <summary>
    /// Number of days the activity lasted at this location
    /// </summary>
    public int NumberOfDays { get; set; }
    
    /// <summary>
    /// Start date of the activity
    /// </summary>
    public DateTime? StartDate { get; set; }
    
    /// <summary>
    /// End date of the activity
    /// </summary>
    public DateTime? EndDate { get; set; }
    
    /// <summary>
    /// Type of activity performed
    /// </summary>
    public string? ActivityType { get; set; }
    
    /// <summary>
    /// Description of the activity
    /// </summary>
    public string? Description { get; set; }
}
