namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Classifies Teams text messages from approvers (Circle Heads, ASMs, RAs) into intents.
/// Separate from the Agency classifier because the intent sets differ.
/// </summary>
public interface ITeamsIntentClassifier
{
    /// <summary>
    /// Classifies the user's text message into an approver-specific intent
    /// </summary>
    /// <param name="userText">The raw text message from the Teams user</param>
    /// <param name="ct">Cancellation token for async operation</param>
    /// <returns>A <see cref="TeamsIntentResult"/> containing the classified intent, confidence, and extracted entities</returns>
    Task<TeamsIntentResult> ClassifyAsync(string userText, CancellationToken ct = default);
}

/// <summary>
/// Result of classifying a Teams approver message into an intent.
/// Contains the intent name, confidence score, and any extracted entities.
/// </summary>
public class TeamsIntentResult
{
    /// <summary>
    /// The classified intent (e.g., PENDING_APPROVALS, SUBMISSION_DETAIL, APPROVED_LIST,
    /// REJECTED_LIST, ACTIVITY_SUMMARY, HELP, GREETING, FALLBACK)
    /// </summary>
    public string Intent { get; set; } = string.Empty;

    /// <summary>
    /// Confidence score for the classification (0.0 to 1.0)
    /// </summary>
    public double Confidence { get; set; }

    /// <summary>
    /// Extracted entities from the user's message
    /// </summary>
    public TeamsIntentEntities Entities { get; set; } = new();
}

/// <summary>
/// Entities extracted from an approver's Teams message during intent classification
/// </summary>
public class TeamsIntentEntities
{
    /// <summary>
    /// A specific FAP ID mentioned in the message (e.g., "FAP-28C9823C"), or null if none
    /// </summary>
    public string? FapId { get; set; }

    /// <summary>
    /// A time range keyword extracted from the message (e.g., "today", "this week"), or null if none
    /// </summary>
    public string? TimeRange { get; set; }
}
