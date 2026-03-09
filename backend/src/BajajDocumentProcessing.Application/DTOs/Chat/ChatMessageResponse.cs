using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Chat;

/// <summary>
/// Response from the chat service containing the AI-generated message and citations
/// </summary>
public class ChatMessageResponse
{
    /// <summary>
    /// Unique identifier of the chat message
    /// </summary>
    [JsonPropertyName("messageId")]
    public required Guid MessageId { get; init; }
    
    /// <summary>
    /// Unique identifier of the conversation
    /// </summary>
    [JsonPropertyName("conversationId")]
    public required Guid ConversationId { get; init; }
    
    /// <summary>
    /// AI-generated response message
    /// </summary>
    [JsonPropertyName("message")]
    public required string Message { get; init; }
    
    /// <summary>
    /// List of data citations supporting the response
    /// </summary>
    [JsonPropertyName("citations")]
    public required List<DataCitationDto> Citations { get; init; }
    
    /// <summary>
    /// UTC timestamp when the message was generated
    /// </summary>
    [JsonPropertyName("timestamp")]
    public required DateTime Timestamp { get; init; }
    
    /// <summary>
    /// Whether the query was authorized (true) or denied (false)
    /// </summary>
    [JsonPropertyName("isAuthorized")]
    public required bool IsAuthorized { get; init; }
    
    /// <summary>
    /// Error message if the query was denied or failed
    /// </summary>
    [JsonPropertyName("errorMessage")]
    public string? ErrorMessage { get; init; }
}
