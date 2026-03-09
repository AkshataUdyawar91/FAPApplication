using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Analytics;

/// <summary>
/// Represents a single KPI metric with its value and metadata
/// </summary>
public class KpiMetricDto
{
    /// <summary>
    /// Name of the KPI metric
    /// </summary>
    [JsonPropertyName("name")]
    public required string Name { get; init; }
    
    /// <summary>
    /// Current value of the metric
    /// </summary>
    [JsonPropertyName("value")]
    public required decimal Value { get; init; }
    
    /// <summary>
    /// Unit of measurement (e.g., "count", "percentage", "seconds")
    /// </summary>
    [JsonPropertyName("unit")]
    public required string Unit { get; init; }
    
    /// <summary>
    /// Change from previous period (positive or negative)
    /// </summary>
    [JsonPropertyName("change")]
    public decimal? Change { get; init; }
    
    /// <summary>
    /// Trend direction (up, down, stable)
    /// </summary>
    [JsonPropertyName("trend")]
    public string? Trend { get; init; }
}
