using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Result of a single proactive validation rule
/// </summary>
public class ProactiveRuleResult
{
    /// <summary>
    /// Rule identifier, e.g. "INV_INVOICE_NUMBER_PRESENT"
    /// </summary>
    [JsonPropertyName("ruleCode")]
    public required string RuleCode { get; init; }

    /// <summary>
    /// Rule type: "Required" or "Check"
    /// </summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }

    /// <summary>
    /// Whether the rule passed
    /// </summary>
    [JsonPropertyName("passed")]
    public required bool Passed { get; init; }

    /// <summary>
    /// Value extracted from the document
    /// </summary>
    [JsonPropertyName("extractedValue")]
    public string? ExtractedValue { get; init; }

    /// <summary>
    /// Expected value for comparison rules
    /// </summary>
    [JsonPropertyName("expectedValue")]
    public string? ExpectedValue { get; init; }

    /// <summary>
    /// Human-readable explanation of the result
    /// </summary>
    [JsonPropertyName("message")]
    public string? Message { get; init; }

    /// <summary>
    /// Severity level: "Pass", "Fail", or "Warning"
    /// </summary>
    [JsonPropertyName("severity")]
    public required string Severity { get; init; }
}
