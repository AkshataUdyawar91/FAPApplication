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
    ReuploadRequested = 5,
    RejectedByASM = 6,
    RejectedByRA = 7,
    PendingRAReview = 8,
    Resubmitted = 9
}
