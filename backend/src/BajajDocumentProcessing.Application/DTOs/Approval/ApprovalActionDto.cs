namespace BajajDocumentProcessing.Application.DTOs.Approval;

/// <summary>
/// DTO representing a single approval action in the audit trail.
/// </summary>
public class ApprovalActionDto
{
    /// <summary>
    /// Unique identifier of the approval action record.
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// Identifier of the document package this action belongs to.
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Display name of the user who performed the action.
    /// </summary>
    public string ActorName { get; set; } = string.Empty;

    /// <summary>
    /// Role of the user who performed the action (e.g., ASM, HQ, Agency).
    /// </summary>
    public string ActorRole { get; set; } = string.Empty;

    /// <summary>
    /// Type of action performed (e.g., ASMApproved, ASMRejected, RAApproved, RARejected, Resubmitted).
    /// </summary>
    public string ActionType { get; set; } = string.Empty;

    /// <summary>
    /// Package state before the action was performed.
    /// </summary>
    public string PreviousState { get; set; } = string.Empty;

    /// <summary>
    /// Package state after the action was performed.
    /// </summary>
    public string NewState { get; set; } = string.Empty;

    /// <summary>
    /// Comment provided by the actor explaining the action.
    /// </summary>
    public string Comment { get; set; } = string.Empty;

    /// <summary>
    /// UTC timestamp when the action was performed.
    /// </summary>
    public DateTime ActionTimestamp { get; set; }
}
