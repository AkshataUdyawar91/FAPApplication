using Microsoft.Bot.Schema;
using Newtonsoft.Json;

namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Hardcoded pilot configuration for Teams Bot testing.
/// In pilot mode, the bot captures the first installer's conversation reference
/// and stores it in memory. No database required.
/// </summary>
public class PilotTeamsConfig
{
    private ConversationReference? _capturedReference;
    private readonly object _lock = new();

    /// <summary>
    /// Whether pilot mode is enabled (from appsettings.json TeamsBot:IsPilotMode).
    /// </summary>
    public bool IsPilotMode { get; set; } = true;

    /// <summary>
    /// Captures the conversation reference when the bot is installed.
    /// Thread-safe — first capture wins, subsequent calls update.
    /// </summary>
    public void CaptureReference(ConversationReference reference)
    {
        lock (_lock)
        {
            _capturedReference = reference;
        }
    }

    /// <summary>
    /// Gets the captured conversation reference for sending proactive messages.
    /// Returns null if no reference has been captured yet.
    /// </summary>
    public ConversationReference? GetReference()
    {
        lock (_lock)
        {
            return _capturedReference;
        }
    }

    /// <summary>
    /// Whether a conversation reference has been captured (bot has been installed by someone).
    /// </summary>
    public bool HasReference
    {
        get
        {
            lock (_lock)
            {
                return _capturedReference != null;
            }
        }
    }
}
