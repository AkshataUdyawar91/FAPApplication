using System.Text.RegularExpressions;
using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;

/// <summary>
/// Phase 1 keyword-based intent classifier for Teams approver messages.
/// Matches user input against predefined keyword sets to determine intent.
/// All matching is case-insensitive on lowercased input.
/// </summary>
public partial class ApproverKeywordClassifier : ITeamsIntentClassifier
{
    private readonly ILogger<ApproverKeywordClassifier> _logger;

    /// <summary>
    /// Regex pattern for extracting FAP IDs (e.g., FAP-28C9823C)
    /// </summary>
    [GeneratedRegex(@"(?:FAP|CIQ-TEST)-\d{4}-\d{4,5}|FAP-[A-Za-z0-9]{6,8}", RegexOptions.IgnoreCase)]
    private static partial Regex FapIdRegex();

    /// <summary>
    /// Keyword sets mapped to each intent, ordered by specificity (most specific first).
    /// Multi-word phrases are checked before single-word keywords to avoid false matches.
    /// </summary>
    private static readonly (string Intent, string[] Keywords)[] IntentKeywords =
    [
        ("SUBMISSION_DETAIL", ["details", "show me", "tell me about"]),
        ("PENDING_APPROVALS", ["new requests", "anything for me", "any open", "open", "pending", "waiting", "approval"]),
        ("APPROVED_LIST", ["how many approved", "approved", "done", "completed"]),
        ("REJECTED_LIST", ["sent back", "rejected", "reject", "return"]),
        ("ACTIVITY_SUMMARY", ["this week", "how many", "summary", "today", "count"]),
        ("HELP", ["what can you do", "help"]),
        ("GREETING", ["good morning", "hello", "hi"]),
    ];

    /// <summary>
    /// Known time range keywords to extract as entities
    /// </summary>
    private static readonly string[] TimeRangeKeywords = ["this month", "last week", "this week", "today"];

    public ApproverKeywordClassifier(ILogger<ApproverKeywordClassifier> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public Task<TeamsIntentResult> ClassifyAsync(string userText, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userText))
        {
            return Task.FromResult(BuildResult("FALLBACK", 0.0));
        }

        var lowered = userText.ToLowerInvariant().Trim();

        // Extract entities first — they inform intent classification
        var fapId = ExtractFapId(userText);
        var timeRange = ExtractTimeRange(lowered);

        // SUBMISSION_DETAIL requires a FAP ID to be present
        if (fapId != null && ContainsAnyKeyword(lowered, IntentKeywords[0].Keywords))
        {
            _logger.LogDebug("Classified as SUBMISSION_DETAIL with FapId {FapId}", fapId);
            return Task.FromResult(BuildResult("SUBMISSION_DETAIL", 1.0, fapId, timeRange));
        }

        // If a FAP ID is present without detail keywords, still treat as SUBMISSION_DETAIL
        if (fapId != null)
        {
            _logger.LogDebug("FAP ID {FapId} found without detail keywords, classifying as SUBMISSION_DETAIL", fapId);
            return Task.FromResult(BuildResult("SUBMISSION_DETAIL", 0.9, fapId, timeRange));
        }

        // Match against keyword sets (skip SUBMISSION_DETAIL since handled above)
        for (var i = 1; i < IntentKeywords.Length; i++)
        {
            var (intent, keywords) = IntentKeywords[i];
            if (ContainsAnyKeyword(lowered, keywords))
            {
                _logger.LogDebug("Classified as {Intent} via keyword match", intent);
                return Task.FromResult(BuildResult(intent, 1.0, null, timeRange));
            }
        }

        _logger.LogDebug("No keyword match for input, returning FALLBACK");
        return Task.FromResult(BuildResult("FALLBACK", 0.0, null, timeRange));
    }

    /// <summary>
    /// Checks if the lowered input contains any of the specified keywords.
    /// Multi-word phrases are matched as substrings; single words use word-boundary logic.
    /// </summary>
    private static bool ContainsAnyKeyword(string lowered, string[] keywords)
    {
        foreach (var keyword in keywords)
        {
            if (keyword.Contains(' '))
            {
                // Multi-word phrase: substring match
                if (lowered.Contains(keyword))
                    return true;
            }
            else
            {
                // Single word: check as whole word to reduce false positives
                // e.g., "open" should match "open requests" but also "any open"
                if (ContainsWord(lowered, keyword))
                    return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Checks if the input contains the word as a standalone token or substring.
    /// Uses simple contains check since keywords are short and specific.
    /// </summary>
    private static bool ContainsWord(string input, string word)
    {
        var index = input.IndexOf(word, StringComparison.Ordinal);
        if (index < 0) return false;

        // Check word boundaries: character before and after should be non-letter
        var before = index == 0 || !char.IsLetter(input[index - 1]);
        var afterIndex = index + word.Length;
        var after = afterIndex >= input.Length || !char.IsLetter(input[afterIndex]);

        return before && after;
    }

    /// <summary>
    /// Extracts a FAP ID from the user's message using regex (case-insensitive).
    /// Returns the matched FAP ID in its original casing, or null if not found.
    /// </summary>
    private static string? ExtractFapId(string text)
    {
        var match = FapIdRegex().Match(text);
        return match.Success ? match.Value : null;
    }

    /// <summary>
    /// Extracts a time range keyword from the lowered input.
    /// Returns the first matching time range, or null if none found.
    /// </summary>
    private static string? ExtractTimeRange(string lowered)
    {
        foreach (var tr in TimeRangeKeywords)
        {
            if (lowered.Contains(tr))
                return tr;
        }

        return null;
    }

    /// <summary>
    /// Builds a <see cref="TeamsIntentResult"/> with the given values.
    /// </summary>
    private static TeamsIntentResult BuildResult(
        string intent,
        double confidence,
        string? fapId = null,
        string? timeRange = null)
    {
        return new TeamsIntentResult
        {
            Intent = intent,
            Confidence = confidence,
            Entities = new TeamsIntentEntities
            {
                FapId = fapId,
                TimeRange = timeRange
            }
        };
    }
}
