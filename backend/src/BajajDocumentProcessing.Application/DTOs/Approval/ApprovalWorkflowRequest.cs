using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Approval;

/// <summary>
/// Request DTO for approval, rejection, and resubmission actions.
/// </summary>
public class ApprovalWorkflowRequest
{
    /// <summary>
    /// Mandatory comment explaining the action (approval reason, rejection reason, or resubmission changes).
    /// </summary>
    [Required(ErrorMessage = "Comment is required")]
    [MinLength(3, ErrorMessage = "Comment must be at least 3 characters")]
    [MaxLength(500, ErrorMessage = "Comment cannot exceed 500 characters")]
    public string Comment { get; set; } = string.Empty;
}
