using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Analytics;

/// <summary>
/// Represents analytics breakdown for a specific campaign
/// </summary>
public class CampaignBreakdownDto
{
    /// <summary>
    /// Campaign name
    /// </summary>
    [JsonPropertyName("campaignName")]
    public required string CampaignName { get; init; }
    
    /// <summary>
    /// Total number of submissions for this campaign
    /// </summary>
    [JsonPropertyName("submissionCount")]
    public required int SubmissionCount { get; init; }
    
    /// <summary>
    /// Number of approved submissions
    /// </summary>
    [JsonPropertyName("approvedCount")]
    public required int ApprovedCount { get; init; }
    
    /// <summary>
    /// Number of rejected submissions
    /// </summary>
    [JsonPropertyName("rejectedCount")]
    public required int RejectedCount { get; init; }
    
    /// <summary>
    /// Number of pending submissions
    /// </summary>
    [JsonPropertyName("pendingCount")]
    public required int PendingCount { get; init; }
    
    /// <summary>
    /// Approval rate as a percentage (0-100)
    /// </summary>
    [JsonPropertyName("approvalRate")]
    public required decimal ApprovalRate { get; init; }
    
    /// <summary>
    /// Total approved amount for this campaign
    /// </summary>
    [JsonPropertyName("totalAmount")]
    public required decimal TotalAmount { get; init; }
}
