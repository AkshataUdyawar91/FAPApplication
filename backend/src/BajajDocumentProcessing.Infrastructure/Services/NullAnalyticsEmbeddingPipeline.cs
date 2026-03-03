using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Null implementation of IAnalyticsEmbeddingPipeline when Azure AI Search is not configured
/// </summary>
public class NullAnalyticsEmbeddingPipeline : IAnalyticsEmbeddingPipeline
{
    private readonly ILogger<NullAnalyticsEmbeddingPipeline> _logger;

    public NullAnalyticsEmbeddingPipeline(ILogger<NullAnalyticsEmbeddingPipeline> logger)
    {
        _logger = logger;
    }

    public Task RunPipelineAsync(DateTime? startDate = null, DateTime? endDate = null, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Analytics pipeline skipped - Azure AI Search not configured");
        return Task.CompletedTask;
    }

    public Task<List<AnalyticsDataPoint>> AggregateAnalyticsDataAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Analytics aggregation skipped - Azure AI Search not configured");
        return Task.FromResult(new List<AnalyticsDataPoint>());
    }

    public Task<List<VectorDocument>> GenerateVectorDocumentsAsync(List<AnalyticsDataPoint> dataPoints, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Vector document generation skipped - Azure AI Search not configured");
        return Task.FromResult(new List<VectorDocument>());
    }
}
