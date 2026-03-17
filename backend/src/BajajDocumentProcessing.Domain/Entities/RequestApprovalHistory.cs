using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Tracks complete approval workflow history for document packages.
/// Records all approval actions (submitted, approved, rejected, resubmitted) with versioning support.
/// </summary>
public class RequestApprovalHistory : BaseEntity
{
    /// <summary>
    /// Foreign key to the document package this approval action belongs to.
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// Foreign key to the user who performed this approval action.
    /// </summary>
    public Guid ApproverId { get; set; }

    /// <summary>
    /// Role of the approver at the time of action (Agency, ASM, RA, Admin).
    /// </summary>
    public UserRole ApproverRole { get; set; }

    /// <summary>
    /// The approval action taken (Submitted, Approved, Rejected, Resubmitted).
    /// </summary>
    public ApprovalAction Action { get; set; }

    /// <summary>
    /// Optional comments provided by the approver explaining their action.
    /// </summary>
    public string? Comments { get; set; }

    /// <summary>
    /// Date and time when this approval action was taken.
    /// </summary>
    public DateTime ActionDate { get; set; }

    /// <summary>
    /// Version number of the package at the time of this action.
    /// Used to track approval history across resubmissions.
    /// </summary>
    public int VersionNumber { get; set; }

    // Navigation properties

    /// <summary>
    /// Navigation property to the document package this approval belongs to.
    /// </summary>
    public DocumentPackage DocumentPackage { get; set; } = null!;

    /// <summary>
    /// Navigation property to the user who performed this approval action.
    /// </summary>
    public User Approver { get; set; } = null!;
}
