using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Conversation message entity
/// </summary>
public class ConversationMessage : BaseEntity
{
    public Guid ConversationId { get; set; }
    public string Role { get; set; } = string.Empty; // "user" or "assistant"
    public string Content { get; set; } = string.Empty;

    // Navigation properties
    public Conversation Conversation { get; set; } = null!;
}
