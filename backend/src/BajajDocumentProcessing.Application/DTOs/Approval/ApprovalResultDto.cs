namespace BajajDocumentProcessing.Application.DTOs.Approval;

/// <summary>
/// Result DTO returned after a successful approval, rejection, or resubmission action.
/// </summary>
public class ApprovalResultDto
{
    /// <summary>
    /// Identifier of the document package that was acted upon.
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// The new state of the document package after the action.
    /// </summary>
    public string NewState { get; set; } = string.Empty;

    /// <summary>
    /// Human-readable message describing the outcome of the action.
    /// </summary>
    public string Message { get; set; } = string.Empty;
}
