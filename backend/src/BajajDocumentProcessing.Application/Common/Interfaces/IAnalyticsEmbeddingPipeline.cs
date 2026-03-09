namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating and managing analytics embeddings for vector search
/// </summary>
public interface IAnalyticsEmbeddingPipeline
{
    /// <summary>
    /// Runs the complete embedding pipeline to generate vector documents from analytics data
    /// </summary>
    /// <param name="startDate">Optional start date for data aggregation (defaults to 30 days ago)</param>
    /// <param name="endDate">Optional end date for data aggregation (defaults to now)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async operation</returns>
    Task RunPipelineAsync(DateTime? startDate = null, DateTime? endDate = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Aggregates analytics data points from submissions for a date range
    /// </summary>
    /// <param name="startDate">Start date of the aggregation period</param>
    /// <param name="endDate">End date of the aggregation period</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of aggregated analytics data points by state and campaign</returns>
    Task<List<AnalyticsDataPoint>> AggregateAnalyticsDataAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default);

    /// <summary>
    /// Generates vector documents with embeddings from analytics data points
    /// </summary>
    /// <param name="dataPoints">Analytics data points to convert to vector documents</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of vector documents with embeddings ready for indexing</returns>
    Task<List<VectorDocument>> GenerateVectorDocumentsAsync(List<AnalyticsDataPoint> dataPoints, CancellationToken cancellationToken = default);
}

/// <summary>
/// Aggregated analytics data point for a specific state/campaign/time period
/// </summary>
public class AnalyticsDataPoint
{
    /// <summary>
    /// Unique identifier for this data point
    /// </summary>
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// State name (optional, null for campaign-level aggregation)
    /// </summary>
    public string? State { get; set; }

    /// <summary>
    /// Campaign name (optional, null for state-level aggregation)
    /// </summary>
    public string? Campaign { get; set; }

    /// <summary>
    /// Start date of the aggregation period
    /// </summary>
    public DateTime StartDate { get; set; }

    /// <summary>
    /// End date of the aggregation period
    /// </summary>
    public DateTime EndDate { get; set; }

    /// <summary>
    /// Total number of submissions in this period
    /// </summary>
    public int SubmissionCount { get; set; }

    /// <summary>
    /// Number of approved submissions
    /// </summary>
    public int ApprovedCount { get; set; }

    /// <summary>
    /// Number of rejected submissions
    /// </summary>
    public int RejectedCount { get; set; }

    /// <summary>
    /// Approval rate as a percentage (0-100)
    /// </summary>
    public double ApprovalRate { get; set; }

    /// <summary>
    /// Average confidence score (0-100)
    /// </summary>
    public double AvgConfidenceScore { get; set; }

    /// <summary>
    /// Average processing time in hours
    /// </summary>
    public double AvgProcessingTimeHours { get; set; }

    /// <summary>
    /// Number of auto-approved submissions
    /// </summary>
    public int AutoApprovalCount { get; set; }
}
