using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Approval;

/// <summary>
/// Request DTO for performing an approval action (approve/reject) on a document package.
/// </summary>
public class ApprovalActionRequest
{
    /// <summary>
    /// The approval action to take: Approved or Rejected.
    /// </summary>
    [Required(ErrorMessage = "Action is required.")]
    [RegularExpression("^(Approved|Rejected)$", ErrorMessage = "Action must be 'Approved' or 'Rejected'.")]
    [JsonPropertyName("action")]
    public required string Action { get; init; }

    /// <summary>
    /// Optional comments explaining the approval decision.
    /// Required when rejecting a submission.
    /// </summary>
    [StringLength(2000, ErrorMessage = "Comments must not exceed 2000 characters.")]
    [JsonPropertyName("comments")]
    public string? Comments { get; init; }
}
