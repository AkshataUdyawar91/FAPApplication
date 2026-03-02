namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Types of notifications in the system
/// </summary>
public enum NotificationType
{
    SubmissionReceived = 1,
    FlaggedForReview = 2,
    Approved = 3,
    Rejected = 4,
    ReuploadRequested = 5
}
