using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Simple message response for operations that don't return data
/// </summary>
public class MessageResponse
{
    /// <summary>
    /// Message describing the result of the operation
    /// </summary>
    [JsonPropertyName("message")]
    public required string Message { get; init; }
}
