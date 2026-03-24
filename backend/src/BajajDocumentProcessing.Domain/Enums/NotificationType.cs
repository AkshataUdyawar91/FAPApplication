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

    /// <summary>
    /// ASM notification when a submission reaches PendingASM and is ready for review.
    /// </summary>
    ReadyForReview = 6
}
