using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a single message within a conversation between a user and the AI assistant
/// </summary>
public class ConversationMessage : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the conversation this message belongs to
    /// </summary>
    public Guid ConversationId { get; set; }
    
    /// <summary>
    /// Gets or sets the role of the message sender ("user" or "assistant")
    /// </summary>
    public string Role { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the text content of the message
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the conversation this message belongs to
    /// </summary>
    public Conversation Conversation { get; set; } = null!;
}
