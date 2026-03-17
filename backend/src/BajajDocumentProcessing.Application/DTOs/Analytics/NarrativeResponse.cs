using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Analytics;

/// <summary>
/// Response containing AI-generated narrative for analytics data
/// </summary>
public class NarrativeResponse
{
    /// <summary>
    /// AI-generated narrative text describing the analytics insights
    /// </summary>
    [JsonPropertyName("narrative")]
    public required string Narrative { get; init; }

    /// <summary>
    /// Timestamp when the narrative was generated
    /// </summary>
    [JsonPropertyName("generatedAt")]
    public required DateTime GeneratedAt { get; init; }
}
