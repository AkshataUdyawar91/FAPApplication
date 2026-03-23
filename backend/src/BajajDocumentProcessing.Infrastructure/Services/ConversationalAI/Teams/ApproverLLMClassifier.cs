using System.Text.Json;
using System.Text.RegularExpressions;
using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;
using Microsoft.SemanticKernel.Connectors.OpenAI;

namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;

/// <summary>
/// Phase 2 LLM-based intent classifier for Teams approver messages.
/// Uses Azure OpenAI GPT-4o-mini to classify natural language into approver intents.
/// Falls back to <see cref="ApproverKeywordClassifier"/> on timeout (&gt;5s) or failure.
/// </summary>
public partial class ApproverLLMClassifier : ITeamsIntentClassifier
{
    private readonly Kernel _kernel;
    private readonly ApproverKeywordClassifier _fallbackClassifier;
    private readonly ILogger<ApproverLLMClassifier> _logger;

    /// <summary>
    /// Maximum time allowed for the LLM call before falling back to keyword classifier.
    /// </summary>
    private static readonly TimeSpan LlmTimeout = TimeSpan.FromSeconds(5);

    /// <summary>
    /// Minimum confidence threshold. Below this, the result is treated as FALLBACK.
    /// </summary>
    private const double MinConfidenceThreshold = 0.7;

    /// <summary>
    /// Valid intents the LLM is expected to return.
    /// </summary>
    private static readonly HashSet<string> ValidIntents = new(StringComparer.OrdinalIgnoreCase)
    {
        "PENDING_APPROVALS", "SUBMISSION_DETAIL", "APPROVED_LIST",
        "REJECTED_LIST", "ACTIVITY_SUMMARY", "HELP", "GREETING", "OUT_OF_SCOPE"
    };

    /// <summary>
    /// Regex for extracting FAP IDs as a safety net (LLM may miss them).
    /// </summary>
    [GeneratedRegex(@"(?:FAP|CIQ-TEST)-\d{4}-\d{4,5}|FAP-[A-Za-z0-9]{6,8}", RegexOptions.IgnoreCase)]
    private static partial Regex FapIdRegex();

    /// <summary>
    /// System prompt instructing GPT-4o-mini to classify approver messages.
    /// </summary>
    private const string SystemPrompt = """
        You are an intent classifier for ClaimsIQ, used by Circle Heads and Regional Approvers.
        Classify the message into exactly one intent. Respond with ONLY JSON.

        Intents:
        - PENDING_APPROVALS: asking about open/pending requests awaiting their approval
        - SUBMISSION_DETAIL: asking about a specific submission (FAP ID mentioned)
        - APPROVED_LIST: asking about what they've approved recently
        - REJECTED_LIST: asking about what they've rejected/returned
        - ACTIVITY_SUMMARY: asking for counts, summary, overview of their queue
        - HELP: asking what the bot can do
        - GREETING: hi, hello
        - OUT_OF_SCOPE: unrelated to approvals

        Entities to extract:
        - fapId: specific FAP ID if mentioned (format: FAP-XXXXXXXX)
        - timeRange: time period ("today", "this week", "this month", "last 3 days")

        Format: {"intent":"PENDING_APPROVALS","confidence":0.95,"entities":{"fapId":null,"timeRange":null}}
        """;

    public ApproverLLMClassifier(
        IConfiguration configuration,
        ApproverKeywordClassifier fallbackClassifier,
        ILogger<ApproverLLMClassifier> logger)
    {
        _fallbackClassifier = fallbackClassifier;
        _logger = logger;

        var endpoint = configuration["AzureOpenAI:Endpoint"]
            ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"]
            ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4o-mini";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        _kernel = builder.Build();
    }

    /// <inheritdoc />
    public async Task<TeamsIntentResult> ClassifyAsync(string userText, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userText))
        {
            return BuildFallbackResult();
        }

        try
        {
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeoutCts.CancelAfter(LlmTimeout);

            var chatHistory = new ChatHistory();
            chatHistory.AddSystemMessage(SystemPrompt);
            chatHistory.AddUserMessage(userText);

            var chatService = _kernel.GetRequiredService<IChatCompletionService>();
            var settings = new OpenAIPromptExecutionSettings
            {
                Temperature = 0.1
            };

            var response = await chatService.GetChatMessageContentAsync(
                chatHistory, settings, kernel: null, timeoutCts.Token);

            var json = response.Content?.Trim();
            if (string.IsNullOrEmpty(json))
            {
                _logger.LogWarning("LLM returned empty response, falling back to keyword classifier");
                return await _fallbackClassifier.ClassifyAsync(userText, ct);
            }

            return ParseLlmResponse(json, userText) ?? await _fallbackClassifier.ClassifyAsync(userText, ct);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            _logger.LogWarning("LLM classification timed out after {Timeout}s, falling back to keyword classifier",
                LlmTimeout.TotalSeconds);
            return await _fallbackClassifier.ClassifyAsync(userText, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "LLM classification failed, falling back to keyword classifier");
            return await _fallbackClassifier.ClassifyAsync(userText, ct);
        }
    }

    /// <summary>
    /// Parses the LLM JSON response into a <see cref="TeamsIntentResult"/>.
    /// Returns null if the JSON is malformed or contains an invalid intent.
    /// </summary>
    private TeamsIntentResult? ParseLlmResponse(string json, string originalText)
    {
        try
        {
            // Strip markdown code fences if the LLM wraps the JSON
            json = json.Trim();
            if (json.StartsWith("```"))
            {
                var startIdx = json.IndexOf('{');
                var endIdx = json.LastIndexOf('}');
                if (startIdx >= 0 && endIdx > startIdx)
                {
                    json = json[startIdx..(endIdx + 1)];
                }
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var intent = root.GetProperty("intent").GetString()?.Trim().ToUpperInvariant();
            var confidence = root.TryGetProperty("confidence", out var confProp)
                ? confProp.GetDouble()
                : 0.0;

            if (string.IsNullOrEmpty(intent) || !ValidIntents.Contains(intent))
            {
                _logger.LogWarning("LLM returned invalid intent '{Intent}'", intent);
                return null;
            }

            // Map OUT_OF_SCOPE to FALLBACK for consistency with the router
            if (intent == "OUT_OF_SCOPE")
            {
                intent = "FALLBACK";
            }

            // Low confidence → return FALLBACK with clarification
            if (confidence < MinConfidenceThreshold)
            {
                _logger.LogDebug("LLM confidence {Confidence} below threshold {Threshold}, returning FALLBACK",
                    confidence, MinConfidenceThreshold);
                return new TeamsIntentResult
                {
                    Intent = "FALLBACK",
                    Confidence = confidence,
                    Entities = new TeamsIntentEntities()
                };
            }

            // Extract entities from LLM response
            string? fapId = null;
            string? timeRange = null;

            if (root.TryGetProperty("entities", out var entities))
            {
                if (entities.TryGetProperty("fapId", out var fapProp) &&
                    fapProp.ValueKind == JsonValueKind.String)
                {
                    fapId = fapProp.GetString();
                }

                if (entities.TryGetProperty("timeRange", out var trProp) &&
                    trProp.ValueKind == JsonValueKind.String)
                {
                    timeRange = trProp.GetString();
                }
            }

            // Safety net: extract FAP ID from original text if LLM missed it
            if (string.IsNullOrEmpty(fapId))
            {
                var match = FapIdRegex().Match(originalText);
                if (match.Success)
                {
                    fapId = match.Value;
                }
            }

            _logger.LogDebug("LLM classified as {Intent} with confidence {Confidence}", intent, confidence);

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
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Failed to parse LLM JSON response: {Json}", json);
            return null;
        }
    }

    /// <summary>
    /// Builds a FALLBACK result for empty/null input.
    /// </summary>
    private static TeamsIntentResult BuildFallbackResult()
    {
        return new TeamsIntentResult
        {
            Intent = "FALLBACK",
            Confidence = 0.0,
            Entities = new TeamsIntentEntities()
        };
    }
}
