using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Chat;

/// <summary>
/// Request to send a chat message to the AI assistant
/// </summary>
public class SendMessageRequest
{
    /// <summary>
    /// User's message/query
    /// </summary>
    [JsonPropertyName("message")]
    [Required(ErrorMessage = "Message is required")]
    [StringLength(500, ErrorMessage = "Message cannot exceed 500 characters")]
    public required string Message { get; init; }
    
    /// <summary>
    /// Optional conversation ID to continue an existing conversation
    /// </summary>
    [JsonPropertyName("conversationId")]
    public Guid? ConversationId { get; init; }
}
