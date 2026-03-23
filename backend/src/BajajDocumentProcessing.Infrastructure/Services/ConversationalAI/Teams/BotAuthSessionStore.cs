using System.Collections.Concurrent;
using BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;

/// <summary>
/// In-memory session store for Teams bot credential-based authentication.
/// Tracks login state per conversation when AAD Object ID is unavailable (emulator/dev).
/// Registered as Singleton so sessions persist across scoped requests.
/// </summary>
public class BotAuthSessionStore
{
    private readonly ConcurrentDictionary<string, BotAuthSession> _sessions = new();

    /// <summary>
    /// Gets the auth session for a conversation, or null if none exists.
    /// </summary>
    public BotAuthSession? GetSession(string conversationId)
    {
        _sessions.TryGetValue(conversationId, out var session);
        return session;
    }

    /// <summary>
    /// Creates or updates the auth session for a conversation.
    /// </summary>
    public void SetSession(string conversationId, BotAuthSession session)
    {
        _sessions[conversationId] = session;
    }

    /// <summary>
    /// Removes the auth session for a conversation (logout).
    /// </summary>
    public void RemoveSession(string conversationId)
    {
        _sessions.TryRemove(conversationId, out _);
    }
}

/// <summary>
/// Represents the authentication state for a single bot conversation.
/// </summary>
public class BotAuthSession
{
    /// <summary>
    /// Current step in the login flow.
    /// </summary>
    public AuthStep Step { get; set; } = AuthStep.AwaitingEmail;

    /// <summary>
    /// Email entered by the user (stored temporarily during login flow).
    /// </summary>
    public string? Email { get; set; }

    /// <summary>
    /// The resolved approver after successful authentication.
    /// </summary>
    public ApproverResolvedUser? ResolvedUser { get; set; }

    /// <summary>
    /// When the session was authenticated (for optional TTL expiry).
    /// </summary>
    public DateTime? AuthenticatedAt { get; set; }
}

/// <summary>
/// Steps in the bot credential login flow.
/// </summary>
public enum AuthStep
{
    AwaitingEmail,
    AwaitingPassword,
    Authenticated
}
