using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Stores Teams conversation references for proactive messaging.
/// Persisted to database so references survive app restarts.
/// </summary>
public class TeamsConversation : BaseEntity
{
    /// <summary>
    /// The Teams user ID (from ChannelAccount.Id)
    /// </summary>
    public string TeamsUserId { get; set; } = string.Empty;

    /// <summary>
    /// The Teams user display name
    /// </summary>
    public string TeamsUserName { get; set; } = string.Empty;

    /// <summary>
    /// The Teams conversation ID
    /// </summary>
    public string ConversationId { get; set; } = string.Empty;

    /// <summary>
    /// The Teams service URL (needed for proactive messaging)
    /// </summary>
    public string ServiceUrl { get; set; } = string.Empty;

    /// <summary>
    /// The Teams channel ID
    /// </summary>
    public string ChannelId { get; set; } = string.Empty;

    /// <summary>
    /// The bot's ID in this conversation
    /// </summary>
    public string BotId { get; set; } = string.Empty;

    /// <summary>
    /// The bot's display name
    /// </summary>
    public string BotName { get; set; } = string.Empty;

    /// <summary>
    /// The tenant ID for the Teams organization
    /// </summary>
    public string? TenantId { get; set; }

    /// <summary>
    /// Serialized ConversationReference JSON for Bot Framework SDK
    /// </summary>
    public string ConversationReferenceJson { get; set; } = string.Empty;

    /// <summary>
    /// Whether this conversation is active (bot not uninstalled)
    /// </summary>
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// Last time a proactive message was sent to this conversation
    /// </summary>
    public DateTime? LastMessageSentAt { get; set; }
}
