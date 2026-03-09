using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a chat conversation between a user and the AI assistant, containing message history
/// </summary>
public class Conversation : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the user who owns this conversation
    /// </summary>
    public Guid UserId { get; set; }
    
    /// <summary>
    /// Gets or sets the timestamp of the most recent message in this conversation
    /// </summary>
    public DateTime LastMessageAt { get; set; }

    /// <summary>
    /// Gets or sets the user who owns this conversation
    /// </summary>
    public User User { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the collection of messages in this conversation
    /// </summary>
    public ICollection<ConversationMessage> Messages { get; set; } = new List<ConversationMessage>();
}
