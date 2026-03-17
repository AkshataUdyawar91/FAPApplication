namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Document package processing states
/// </summary>
public enum PackageState
{
    Draft = 0,
    Uploaded = 1,
    Extracting = 2,
    Validating = 3,
    PendingASM = 4,
    ASMRejected = 5,
    PendingRA = 6,
    RARejected = 7,
    Approved = 8
}
