namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Cost Summary extracted data
/// </summary>
public class CostSummaryData
{
    public string CampaignName { get; set; } = string.Empty;
    public string State { get; set; } = string.Empty;
    public DateTime CampaignStartDate { get; set; }
    public DateTime CampaignEndDate { get; set; }
    public List<CostBreakdown> CostBreakdowns { get; set; } = new();
    public decimal TotalCost { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Cost breakdown by category
/// </summary>
public class CostBreakdown
{
    public string Category { get; set; } = string.Empty;
    public decimal Amount { get; set; }
}
