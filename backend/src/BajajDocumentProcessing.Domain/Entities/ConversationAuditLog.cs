using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Write-only audit record for every conversational AI interaction (Agency bot and Teams bot).
/// Logs user messages, bot responses, and classified intents for compliance and analytics.
/// </summary>
public class ConversationAuditLog : BaseEntity
{
    /// <summary>
    /// The resolved ClaimsIQ user who sent the message
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// Role of the user at the time of the interaction (e.g. "ASM", "RA", "Agency")
    /// </summary>
    public string UserRole { get; set; } = string.Empty;

    /// <summary>
    /// Channel the message was received on (e.g. "TeamsBot", "AgencyBot")
    /// </summary>
    public string Channel { get; set; } = string.Empty;

    /// <summary>
    /// The raw text message sent by the user
    /// </summary>
    public string UserMessage { get; set; } = string.Empty;

    /// <summary>
    /// The bot's response text (or summary for card responses)
    /// </summary>
    public string BotResponse { get; set; } = string.Empty;

    /// <summary>
    /// Comma-separated list of states the user was scoped to at the time of the interaction.
    /// Captures the approver's jurisdiction for audit purposes.
    /// </summary>
    public string? ResolvedScope { get; set; }

    /// <summary>
    /// The classified intent (e.g. "PENDING_APPROVALS", "SUBMISSION_DETAIL", "FALLBACK")
    /// </summary>
    public string? Intent { get; set; }

    /// <summary>
    /// UTC timestamp when the interaction occurred
    /// </summary>
    public DateTime Timestamp { get; set; }
}
