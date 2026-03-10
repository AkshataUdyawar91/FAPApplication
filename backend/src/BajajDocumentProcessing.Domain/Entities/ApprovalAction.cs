using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an approval workflow action (approve, reject, or resubmit) performed on a document package.
/// Forms an append-only audit trail of all approval decisions with actor identity, comment, and state transitions
/// </summary>
public class ApprovalAction : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the document package this action belongs to
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Gets or sets the unique identifier of the user who performed this action
    /// </summary>
    public Guid ActorUserId { get; set; }

    /// <summary>
    /// Gets or sets the type of approval action performed (ASMApproved, ASMRejected, RAApproved, RARejected, Resubmitted)
    /// </summary>
    public ApprovalActionType ActionType { get; set; }

    /// <summary>
    /// Gets or sets the package state before this action was performed
    /// </summary>
    public PackageState PreviousState { get; set; }

    /// <summary>
    /// Gets or sets the package state after this action was performed
    /// </summary>
    public PackageState NewState { get; set; }

    /// <summary>
    /// Gets or sets the mandatory comment provided by the actor explaining the action
    /// </summary>
    public string Comment { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the UTC timestamp when this action was performed
    /// </summary>
    public DateTime ActionTimestamp { get; set; }

    /// <summary>
    /// Gets or sets the document package this action belongs to
    /// </summary>
    public DocumentPackage Package { get; set; } = null!;

    /// <summary>
    /// Gets or sets the user who performed this action
    /// </summary>
    public User ActorUser { get; set; } = null!;
}
