using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Dealer typeahead result from the StateMapping table
/// </summary>
public class DealerResult
{
    /// <summary>
    /// Dealer code identifier
    /// </summary>
    [JsonPropertyName("dealerCode")]
    public required string DealerCode { get; init; }

    /// <summary>
    /// Dealer name
    /// </summary>
    [JsonPropertyName("dealerName")]
    public required string DealerName { get; init; }

    /// <summary>
    /// City where the dealer is located
    /// </summary>
    [JsonPropertyName("city")]
    public required string City { get; init; }

    /// <summary>
    /// State where the dealer is located
    /// </summary>
    [JsonPropertyName("state")]
    public required string State { get; init; }
}
