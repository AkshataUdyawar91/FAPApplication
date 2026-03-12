namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Represents the type of approval action taken on a document package.
/// Used in RequestApprovalHistory to track workflow actions.
/// </summary>
public enum ApprovalAction
{
    /// <summary>
    /// Package was submitted for review.
    /// </summary>
    Submitted = 1,

    /// <summary>
    /// Package was approved by the reviewer.
    /// </summary>
    Approved = 2,

    /// <summary>
    /// Package was rejected by the reviewer.
    /// </summary>
    Rejected = 3,

    /// <summary>
    /// Package was resubmitted after rejection.
    /// </summary>
    Resubmitted = 4
}
