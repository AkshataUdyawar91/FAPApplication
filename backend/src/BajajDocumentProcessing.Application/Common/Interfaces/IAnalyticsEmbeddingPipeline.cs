namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IAnalyticsEmbeddingPipeline
{
    Task RunPipelineAsync(DateTime? startDate = null, DateTime? endDate = null, CancellationToken cancellationToken = default);
    Task<List<AnalyticsDataPoint>> AggregateAnalyticsDataAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);
    Task<List<VectorDocument>> GenerateVectorDocumentsAsync(List<AnalyticsDataPoint> dataPoints, CancellationToken cancellationToken = default);
}

public class AnalyticsDataPoint
{
    public string Id { get; set; } = string.Empty;
    public string? State { get; set; }
    public string? Campaign { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public int SubmissionCount { get; set; }
    public int ApprovedCount { get; set; }
    public int RejectedCount { get; set; }
    public double ApprovalRate { get; set; }
    public double AvgConfidenceScore { get; set; }
    public double AvgProcessingTimeHours { get; set; }
    public int AutoApprovalCount { get; set; }
}
