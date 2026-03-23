namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

/// <summary>
/// Aggregate activity summary for an approver, used for the ACTIVITY_SUMMARY intent response.
/// All counts and amounts are scoped to the approver's assigned state(s).
/// </summary>
public class ApproverActivitySummary
{
    /// <summary>
    /// Total number of submissions currently pending the approver's review
    /// </summary>
    public int PendingCount { get; set; }

    /// <summary>
    /// Number of new submissions received today within the approver's scope
    /// </summary>
    public int NewToday { get; set; }

    /// <summary>
    /// Number of submissions approved by this approver in the current week
    /// </summary>
    public int ApprovedThisWeek { get; set; }

    /// <summary>
    /// Total amount (INR) of submissions approved by this approver in the current week
    /// </summary>
    public decimal ApprovedAmountThisWeek { get; set; }

    /// <summary>
    /// Number of submissions rejected by this approver in the current week
    /// </summary>
    public int RejectedThisWeek { get; set; }

    /// <summary>
    /// Average number of days from submission to approval/rejection for this approver
    /// </summary>
    public double AvgProcessingDays { get; set; }
}
