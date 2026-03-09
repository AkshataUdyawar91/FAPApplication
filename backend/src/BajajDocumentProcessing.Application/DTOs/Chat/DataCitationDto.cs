using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Chat;

/// <summary>
/// Represents a data source citation in a chat response
/// </summary>
public class DataCitationDto
{
    /// <summary>
    /// Source of the data (e.g., "Analytics Database", "Submission #12345")
    /// </summary>
    [JsonPropertyName("source")]
    public required string Source { get; init; }
    
    /// <summary>
    /// Time range of the data cited
    /// </summary>
    [JsonPropertyName("timeRange")]
    public string? TimeRange { get; init; }
    
    /// <summary>
    /// Specific data point or metric cited
    /// </summary>
    [JsonPropertyName("dataPoint")]
    public required string DataPoint { get; init; }
    
    /// <summary>
    /// Value of the cited data
    /// </summary>
    [JsonPropertyName("value")]
    public required string Value { get; init; }
}
