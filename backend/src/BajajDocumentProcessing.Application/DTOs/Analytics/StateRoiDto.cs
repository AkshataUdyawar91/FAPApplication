using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Analytics;

/// <summary>
/// Represents ROI metrics for a specific state
/// </summary>
public class StateRoiDto
{
    /// <summary>
    /// State name
    /// </summary>
    [JsonPropertyName("state")]
    public required string State { get; init; }
    
    /// <summary>
    /// Total number of submissions from this state
    /// </summary>
    [JsonPropertyName("submissionCount")]
    public required int SubmissionCount { get; init; }
    
    /// <summary>
    /// Total approved amount for this state
    /// </summary>
    [JsonPropertyName("approvedAmount")]
    public required decimal ApprovedAmount { get; init; }
    
    /// <summary>
    /// Approval rate as a percentage (0-100)
    /// </summary>
    [JsonPropertyName("approvalRate")]
    public required decimal ApprovalRate { get; init; }
    
    /// <summary>
    /// Average processing time in hours
    /// </summary>
    [JsonPropertyName("avgProcessingTime")]
    public required decimal AvgProcessingTime { get; init; }
    
    /// <summary>
    /// Return on investment percentage
    /// </summary>
    [JsonPropertyName("roi")]
    public required decimal Roi { get; init; }
}
