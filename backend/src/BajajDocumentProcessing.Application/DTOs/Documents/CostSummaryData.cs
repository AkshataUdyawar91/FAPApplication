namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Cost Summary extracted data
/// </summary>
public class CostSummaryData
{
    /// <summary>
    /// Name of the campaign
    /// </summary>
    public string CampaignName { get; set; } = string.Empty;
    
    /// <summary>
    /// State where the campaign took place
    /// </summary>
    public string State { get; set; } = string.Empty;
    
    /// <summary>
    /// Place of supply for GST purposes
    /// </summary>
    public string? PlaceOfSupply { get; set; }
    
    /// <summary>
    /// Campaign start date
    /// </summary>
    public DateTime CampaignStartDate { get; set; }
    
    /// <summary>
    /// Campaign end date
    /// </summary>
    public DateTime CampaignEndDate { get; set; }
    
    /// <summary>
    /// List of cost breakdowns by category
    /// </summary>
    public List<CostBreakdown> CostBreakdowns { get; set; } = new();
    
    /// <summary>
    /// Total cost across all categories
    /// </summary>
    public decimal TotalCost { get; set; }
    
    /// <summary>
    /// Total number of days the campaign ran
    /// </summary>
    public int? NumberOfDays { get; set; }
    
    /// <summary>
    /// Number of teams involved in the campaign
    /// </summary>
    public int? NumberOfTeams { get; set; }
    
    /// <summary>
    /// Number of activations performed
    /// </summary>
    public int? NumberOfActivations { get; set; }
    
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
/// Cost breakdown by category
/// </summary>
public class CostBreakdown
{
    /// <summary>
    /// Cost category (e.g., "Manpower", "Travel", "Materials")
    /// </summary>
    public string Category { get; set; } = string.Empty;
    
    /// <summary>
    /// Specific element name within the category
    /// </summary>
    public string? ElementName { get; set; }
    
    /// <summary>
    /// Cost amount for this category
    /// </summary>
    public decimal Amount { get; set; }
    
    /// <summary>
    /// Quantity of items in this category
    /// </summary>
    public int? Quantity { get; set; }
    
    /// <summary>
    /// Unit of measurement (e.g., "days", "pieces", "hours")
    /// </summary>
    public string? Unit { get; set; }
    
    /// <summary>
    /// Whether this is a fixed cost
    /// </summary>
    public bool IsFixedCost { get; set; }
    
    /// <summary>
    /// Whether this is a variable cost
    /// </summary>
    public bool IsVariableCost { get; set; }
}
