namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

/// <summary>
/// Represents a resolved approver identity from a Teams AAD Object ID lookup.
/// Contains the user's role and assigned states for scoping approval queries.
/// </summary>
public class ApproverResolvedUser
{
    /// <summary>
    /// The ClaimsIQ user identifier
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// The approver's role — "ASM" or "RA"
    /// </summary>
    public string Role { get; set; } = string.Empty;

    /// <summary>
    /// The approver's display name for personalized responses
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    /// The state(s) assigned to this approver for query scoping.
    /// ASMs typically have one state; RAs may have multiple.
    /// </summary>
    public string[] AssignedStates { get; set; } = Array.Empty<string>();
}
