using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Conversation entity for chat history
/// </summary>
public class Conversation : BaseEntity
{
    public Guid UserId { get; set; }
    public DateTime LastMessageAt { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public ICollection<ConversationMessage> Messages { get; set; } = new List<ConversationMessage>();
}
