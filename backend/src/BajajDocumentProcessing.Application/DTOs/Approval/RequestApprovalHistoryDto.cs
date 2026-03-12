using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Approval;

/// <summary>
/// DTO representing an approval history entry for a document package.
/// </summary>
public class RequestApprovalHistoryDto
{
    /// <summary>
    /// Unique identifier of the approval history entry.
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }

    /// <summary>
    /// Document package ID this action belongs to.
    /// </summary>
    [JsonPropertyName("packageId")]
    public required Guid PackageId { get; init; }

    /// <summary>
    /// User ID of the approver who performed this action.
    /// </summary>
    [JsonPropertyName("approverId")]
    public required Guid ApproverId { get; init; }

    /// <summary>
    /// Display name of the approver.
    /// </summary>
    [JsonPropertyName("approverName")]
    public string? ApproverName { get; init; }

    /// <summary>
    /// Role of the approver (Agency, ASM, RA, Admin).
    /// </summary>
    [JsonPropertyName("approverRole")]
    public required string ApproverRole { get; init; }

    /// <summary>
    /// Action taken (Submitted, Approved, Rejected, Resubmitted).
    /// </summary>
    [JsonPropertyName("action")]
    public required string Action { get; init; }

    /// <summary>
    /// Optional comments provided by the approver.
    /// </summary>
    [JsonPropertyName("comments")]
    public string? Comments { get; init; }

    /// <summary>
    /// UTC timestamp when the action was taken.
    /// </summary>
    [JsonPropertyName("actionDate")]
    public required DateTime ActionDate { get; init; }

    /// <summary>
    /// Package version at the time of this action.
    /// </summary>
    [JsonPropertyName("versionNumber")]
    public required int VersionNumber { get; init; }
}
