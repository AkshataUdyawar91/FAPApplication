using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// A tappable action button rendered below a bot message
/// </summary>
public class ActionButton
{
    /// <summary>
    /// Display label for the button
    /// </summary>
    [JsonPropertyName("label")]
    public required string Label { get; init; }

    /// <summary>
    /// Action identifier sent back in ConversationRequest.Action
    /// </summary>
    [JsonPropertyName("action")]
    public required string Action { get; init; }

    /// <summary>
    /// Optional structured payload sent back in ConversationRequest.PayloadJson
    /// </summary>
    [JsonPropertyName("payloadJson")]
    public string? PayloadJson { get; init; }
}
