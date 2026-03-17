using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Analytics;

/// <summary>
/// Complete analytics dashboard data including KPIs, state ROI, and campaign breakdowns
/// </summary>
public class DashboardDataResponse
{
    /// <summary>
    /// List of KPI metrics
    /// </summary>
    [JsonPropertyName("kpis")]
    public required List<KpiMetricDto> Kpis { get; init; }
    
    /// <summary>
    /// State-level ROI metrics
    /// </summary>
    [JsonPropertyName("stateRoi")]
    public required List<StateRoiDto> StateRoi { get; init; }
    
    /// <summary>
    /// Campaign breakdown analytics
    /// </summary>
    [JsonPropertyName("campaignBreakdown")]
    public required List<CampaignBreakdownDto> CampaignBreakdown { get; init; }
    
    /// <summary>
    /// AI-generated narrative summarizing key insights
    /// </summary>
    [JsonPropertyName("aiNarrative")]
    public string? AiNarrative { get; init; }
    
    /// <summary>
    /// UTC timestamp when the data was generated
    /// </summary>
    [JsonPropertyName("generatedAt")]
    public required DateTime GeneratedAt { get; init; }
}
