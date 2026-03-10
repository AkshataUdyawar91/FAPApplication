namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Document package processing states
/// </summary>
public enum PackageState
{
    Uploaded = 1,
    Extracting = 2,
    Validating = 3,
    Validated = 4,
    ValidationFailed = 5,
    Scoring = 6,
    Recommending = 7,
    PendingASMApproval = 8,      // Waiting for ASM approval
    ASMApproved = 9,              // ASM approved, pending RA approval
    PendingHQApproval = 10,       // Waiting for RA approval (HQ is legacy name, means RA)
    Approved = 11,                // Final approval by RA
    RejectedByASM = 12,           // Rejected by ASM, goes back to Agency
    RejectedByRA = 13,            // Rejected by RA, goes back to ASM
    ReuploadRequested = 14,       // Agency needs to reupload
    
    // Legacy states for backward compatibility
    PendingApproval = 8,          // Alias for PendingASMApproval
    Rejected = 12,                // Alias for RejectedByASM
    RejectedByHQ = 13             // Legacy alias for RejectedByRA
}
