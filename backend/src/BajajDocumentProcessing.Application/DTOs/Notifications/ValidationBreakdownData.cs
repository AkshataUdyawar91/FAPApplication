namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// DTO containing per-document validation breakdown data for the Review Details card.
/// Groups validation checks by type with pass/fail status.
/// </summary>
public class ValidationBreakdownData
{
    /// <summary>
    /// Unique identifier of the submission (DocumentPackage.Id).
    /// </summary>
    public Guid SubmissionId { get; set; }

    /// <summary>
    /// Human-readable submission number in the format "FAP-{shortId}".
    /// </summary>
    public string SubmissionNumber { get; set; } = string.Empty;

    /// <summary>
    /// Current PackageState as a display string.
    /// </summary>
    public string CurrentStatus { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp of the latest approval/rejection action, if already processed.
    /// </summary>
    public DateTime? ProcessedAt { get; set; }

    /// <summary>
    /// Name of the approver/rejector, if already processed.
    /// </summary>
    public string? ProcessedBy { get; set; }

    /// <summary>
    /// Whether the submission has already been processed (State != PendingASM).
    /// </summary>
    public bool IsAlreadyProcessed { get; set; }

    /// <summary>
    /// Validation checks grouped by type (e.g., SAP Verification, Amount Consistency).
    /// </summary>
    public List<ValidationCheckGroup> CheckGroups { get; set; } = new();

    /// <summary>
    /// Deep link URL to the portal review page for this submission.
    /// </summary>
    public string PortalUrl { get; set; } = string.Empty;
}

/// <summary>
/// Represents a group of related validation checks with an overall status.
/// </summary>
public class ValidationCheckGroup
{
    /// <summary>
    /// Name of the validation check group (e.g., "SAP Verification", "Amount Consistency").
    /// </summary>
    public string GroupName { get; set; } = string.Empty;

    /// <summary>
    /// Overall status of the check group: "Pass" or "Fail".
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Optional detailed issue description from ValidationDetailsJson.
    /// </summary>
    public string? Details { get; set; }
}
