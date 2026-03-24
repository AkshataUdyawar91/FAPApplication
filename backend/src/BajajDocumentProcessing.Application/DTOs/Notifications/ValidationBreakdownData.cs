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

    /// <summary>
    /// Per-document SAS-signed URLs for viewing documents directly from Teams.
    /// Key = document type label (e.g., "Invoice", "Cost Summary"), Value = SAS URL.
    /// </summary>
    public Dictionary<string, string> DocumentViewUrls { get; set; } = new();

    /// <summary>
    /// SAS-signed URLs for team photos, grouped by team name.
    /// Each entry contains photo file name and SAS URL.
    /// </summary>
    public List<TeamPhotoViewData> TeamPhotos { get; set; } = new();
}

/// <summary>
/// Represents a team's photos with SAS-signed URLs for inline viewing.
/// </summary>
public class TeamPhotoViewData
{
    /// <summary>
    /// Team name or identifier.
    /// </summary>
    public string TeamName { get; set; } = string.Empty;

    /// <summary>
    /// Photos belonging to this team with SAS URLs.
    /// </summary>
    public List<PhotoViewItem> Photos { get; set; } = new();
}

/// <summary>
/// A single photo with its SAS-signed URL and metadata.
/// </summary>
public class PhotoViewItem
{
    /// <summary>
    /// Original file name of the photo.
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// SAS-signed URL for viewing the photo.
    /// </summary>
    public string ViewUrl { get; set; } = string.Empty;

    /// <summary>
    /// Optional caption or description.
    /// </summary>
    public string? Caption { get; set; }

    /// <summary>
    /// Summary of failed validation checks for this photo (e.g., "Date not visible, No blue t-shirt").
    /// </summary>
    public string? FailedChecks { get; set; }
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

    /// <summary>
    /// Evidence text with actual extracted values (shown for both pass and fail).
    /// Example: "PO found in SAP", "Invoice total ₹1,41,600 vs PO amount ₹1,75,000".
    /// </summary>
    public string? Evidence { get; set; }
}
