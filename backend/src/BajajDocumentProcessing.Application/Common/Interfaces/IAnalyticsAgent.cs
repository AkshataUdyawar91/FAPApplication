namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating analytics dashboards and KPI metrics
/// </summary>
public interface IAnalyticsAgent
{
    /// <summary>
    /// Retrieves KPI dashboard data for a date range
    /// </summary>
    /// <param name="startDate">Start date of the reporting period</param>
    /// <param name="endDate">End date of the reporting period</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>KPI dashboard with submission metrics and approval rates</returns>
    Task<KPIDashboard> GetKPIsAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves state-wise ROI analysis for a date range
    /// </summary>
    /// <param name="startDate">Start date of the reporting period</param>
    /// <param name="endDate">End date of the reporting period</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of state ROI metrics with submission counts and approval rates</returns>
    Task<List<StateROI>> GetStateROIAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves campaign-wise breakdown for a date range
    /// </summary>
    /// <param name="startDate">Start date of the reporting period</param>
    /// <param name="endDate">End date of the reporting period</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of campaign metrics with submission counts and approval rates</returns>
    Task<List<CampaignBreakdown>> GetCampaignBreakdownAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);

    /// <summary>
    /// Exports analytics data to Excel format
    /// </summary>
    /// <param name="startDate">Start date of the reporting period</param>
    /// <param name="endDate">End date of the reporting period</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Excel file as byte array</returns>
    Task<byte[]> ExportToExcelAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);

    /// <summary>
    /// Generates AI-powered narrative summary of KPI data
    /// </summary>
    /// <param name="kpis">KPI dashboard data to summarize</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Natural language narrative describing key insights</returns>
    Task<string> GenerateNarrativeAsync(KPIDashboard kpis, CancellationToken cancellationToken = default);
}

/// <summary>
/// KPI dashboard data with submission metrics and approval rates
/// </summary>
public class KPIDashboard
{
    /// <summary>
    /// Start date of the reporting period
    /// </summary>
    public DateTime StartDate { get; set; }

    /// <summary>
    /// End date of the reporting period
    /// </summary>
    public DateTime EndDate { get; set; }

    /// <summary>
    /// Total number of submissions in the period
    /// </summary>
    public int TotalSubmissions { get; set; }

    /// <summary>
    /// Number of approved submissions
    /// </summary>
    public int ApprovedCount { get; set; }

    /// <summary>
    /// Number of rejected submissions
    /// </summary>
    public int RejectedCount { get; set; }

    /// <summary>
    /// Number of pending submissions
    /// </summary>
    public int PendingCount { get; set; }

    /// <summary>
    /// Approval rate as a percentage (0-100)
    /// </summary>
    public double ApprovalRate { get; set; }

    /// <summary>
    /// Average processing time in hours
    /// </summary>
    public double AvgProcessingTimeHours { get; set; }

    /// <summary>
    /// Number of auto-approved submissions
    /// </summary>
    public int AutoApprovalCount { get; set; }

    /// <summary>
    /// Auto-approval rate as a percentage (0-100)
    /// </summary>
    public double AutoApprovalRate { get; set; }

    /// <summary>
    /// Average confidence score across all submissions (0-100)
    /// </summary>
    public double AvgConfidenceScore { get; set; }

    /// <summary>
    /// Distribution of submissions by confidence score ranges
    /// </summary>
    public Dictionary<string, int> ConfidenceDistribution { get; set; } = new();
}

/// <summary>
/// State-wise ROI analysis data
/// </summary>
public class StateROI
{
    /// <summary>
    /// State name
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// Number of submissions from this state
    /// </summary>
    public int SubmissionCount { get; set; }

    /// <summary>
    /// Number of approved submissions from this state
    /// </summary>
    public int ApprovedCount { get; set; }

    /// <summary>
    /// Approval rate for this state as a percentage (0-100)
    /// </summary>
    public double ApprovalRate { get; set; }

    /// <summary>
    /// Average confidence score for submissions from this state (0-100)
    /// </summary>
    public double AvgConfidenceScore { get; set; }

    /// <summary>
    /// Return on investment metric for this state
    /// </summary>
    public double ROI { get; set; }
}

/// <summary>
/// Campaign-wise breakdown data
/// </summary>
public class CampaignBreakdown
{
    /// <summary>
    /// Campaign name
    /// </summary>
    public string Campaign { get; set; } = string.Empty;

    /// <summary>
    /// Number of submissions for this campaign
    /// </summary>
    public int SubmissionCount { get; set; }

    /// <summary>
    /// Number of approved submissions for this campaign
    /// </summary>
    public int ApprovedCount { get; set; }

    /// <summary>
    /// Approval rate for this campaign as a percentage (0-100)
    /// </summary>
    public double ApprovalRate { get; set; }

    /// <summary>
    /// Average confidence score for submissions in this campaign (0-100)
    /// </summary>
    public double AvgConfidenceScore { get; set; }
}
