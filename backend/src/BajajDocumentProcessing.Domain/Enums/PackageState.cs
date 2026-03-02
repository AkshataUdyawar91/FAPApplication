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
    PendingApproval = 8,
    Approved = 9,
    Rejected = 10,
    ReuploadRequested = 11
}
