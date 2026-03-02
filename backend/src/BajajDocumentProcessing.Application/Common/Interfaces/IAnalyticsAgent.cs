namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IAnalyticsAgent
{
    Task<KPIDashboard> GetKPIsAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);
    Task<List<StateROI>> GetStateROIAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);
    Task<List<CampaignBreakdown>> GetCampaignBreakdownAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);
    Task<byte[]> ExportToExcelAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);
    Task<string> GenerateNarrativeAsync(KPIDashboard kpis, CancellationToken cancellationToken = default);
}

public class KPIDashboard
{
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public int TotalSubmissions { get; set; }
    public int ApprovedCount { get; set; }
    public int RejectedCount { get; set; }
    public int PendingCount { get; set; }
    public double ApprovalRate { get; set; }
    public double AvgProcessingTimeHours { get; set; }
    public int AutoApprovalCount { get; set; }
    public double AutoApprovalRate { get; set; }
    public double AvgConfidenceScore { get; set; }
    public Dictionary<string, int> ConfidenceDistribution { get; set; } = new();
}

public class StateROI
{
    public string State { get; set; } = string.Empty;
    public int SubmissionCount { get; set; }
    public int ApprovedCount { get; set; }
    public double ApprovalRate { get; set; }
    public double AvgConfidenceScore { get; set; }
    public double ROI { get; set; }
}

public class CampaignBreakdown
{
    public string Campaign { get; set; } = string.Empty;
    public int SubmissionCount { get; set; }
    public int ApprovedCount { get; set; }
    public double ApprovalRate { get; set; }
    public double AvgConfidenceScore { get; set; }
}
