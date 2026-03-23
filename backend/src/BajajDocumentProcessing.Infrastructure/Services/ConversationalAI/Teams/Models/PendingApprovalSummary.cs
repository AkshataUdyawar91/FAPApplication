namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

/// <summary>
/// Summary of a single pending approval item for display in Teams Adaptive Cards.
/// Projected from DocumentPackage queries scoped to the approver.
/// </summary>
public class PendingApprovalSummary
{
    /// <summary>
    /// The FAP identifier for the submission (e.g., "FAP-28C9823C")
    /// </summary>
    public string FapId { get; set; } = string.Empty;

    /// <summary>
    /// The submission's unique identifier, needed for card action data
    /// </summary>
    public Guid SubmissionId { get; set; }

    /// <summary>
    /// The name of the agency that submitted the package
    /// </summary>
    public string AgencyName { get; set; } = string.Empty;

    /// <summary>
    /// The invoice amount in INR
    /// </summary>
    public decimal Amount { get; set; }

    /// <summary>
    /// The date and time the submission was created
    /// </summary>
    public DateTime SubmittedAt { get; set; }

    /// <summary>
    /// Number of days the submission has been pending approval
    /// </summary>
    public int DaysPending { get; set; }

    /// <summary>
    /// The state associated with this submission
    /// </summary>
    public string State { get; set; } = string.Empty;
}
