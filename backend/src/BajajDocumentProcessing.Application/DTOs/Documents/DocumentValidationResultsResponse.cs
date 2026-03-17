using System.Text.Json.Serialization;
using BajajDocumentProcessing.Application.DTOs.Conversation;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Response for per-document proactive validation results
/// </summary>
public class DocumentValidationResultsResponse
{
    /// <summary>
    /// Per-rule validation results
    /// </summary>
    [JsonPropertyName("rules")]
    public List<ProactiveRuleResult> Rules { get; set; } = new();
}
