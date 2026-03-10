namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Types of actions that can be performed in the approval workflow
/// </summary>
public enum ApprovalActionType
{
    ASMApproved = 1,
    ASMRejected = 2,
    RAApproved = 3,
    RARejected = 4,
    Resubmitted = 5
}
