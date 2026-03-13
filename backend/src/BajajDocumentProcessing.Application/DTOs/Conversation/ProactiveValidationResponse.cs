using System.Text.Json.Serialization;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Response from proactive per-document validation after extraction
/// </summary>
public class ProactiveValidationResponse
{
    /// <summary>
    /// The validated document identifier
    /// </summary>
    [JsonPropertyName("documentId")]
    public required Guid DocumentId { get; init; }

    /// <summary>
    /// Type of document that was validated
    /// </summary>
    [JsonPropertyName("documentType")]
    public required DocumentType DocumentType { get; init; }

    /// <summary>
    /// Whether all rules passed
    /// </summary>
    [JsonPropertyName("allPassed")]
    public required bool AllPassed { get; init; }

    /// <summary>
    /// Number of rules that passed
    /// </summary>
    [JsonPropertyName("passCount")]
    public required int PassCount { get; init; }

    /// <summary>
    /// Number of rules that failed
    /// </summary>
    [JsonPropertyName("failCount")]
    public required int FailCount { get; init; }

    /// <summary>
    /// Number of rules with warnings
    /// </summary>
    [JsonPropertyName("warningCount")]
    public required int WarningCount { get; init; }

    /// <summary>
    /// Per-rule validation results
    /// </summary>
    [JsonPropertyName("rules")]
    public required List<ProactiveRuleResult> Rules { get; init; }
}
