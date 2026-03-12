using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class AnalyticsEmbeddingPipeline : IAnalyticsEmbeddingPipeline
{
    private readonly IApplicationDbContext _context;
    private readonly IEmbeddingService _embeddingService;
    private readonly IVectorSearchService _vectorSearchService;
    private readonly ILogger<AnalyticsEmbeddingPipeline> _logger;

    public AnalyticsEmbeddingPipeline(
        IApplicationDbContext context,
        IEmbeddingService embeddingService,
        IVectorSearchService vectorSearchService,
        ILogger<AnalyticsEmbeddingPipeline> logger)
    {
        _context = context;
        _embeddingService = embeddingService;
        _vectorSearchService = vectorSearchService;
        _logger = logger;
    }

    public async Task RunPipelineAsync(
        DateTime? startDate = null,
        DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Default to previous day if not specified
            var start = startDate ?? DateTime.UtcNow.AddDays(-1).Date;
            var end = endDate ?? DateTime.UtcNow.Date;

            _logger.LogInformation("Starting analytics embedding pipeline for date range {StartDate} to {EndDate}", start, end);

            // Step 1: Aggregate analytics data
            var dataPoints = await AggregateAnalyticsDataAsync(start, end, cancellationToken);
            _logger.LogInformation("Aggregated {Count} analytics data points", dataPoints.Count);

            if (!dataPoints.Any())
            {
                _logger.LogInformation("No data points to process");
                return;
            }

            // Step 2: Generate vector documents with embeddings
            var vectorDocuments = await GenerateVectorDocumentsAsync(dataPoints, cancellationToken);
            _logger.LogInformation("Generated {Count} vector documents", vectorDocuments.Count);

            // Step 3: Upsert to vector database
            await _vectorSearchService.UpsertDocumentsAsync(vectorDocuments, cancellationToken);
            _logger.LogInformation("Successfully upserted {Count} documents to vector database", vectorDocuments.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Analytics embedding pipeline failed");
            throw;
        }
    }

    public async Task<List<AnalyticsDataPoint>> AggregateAnalyticsDataAsync(
        DateTime startDate,
        DateTime endDate,
        CancellationToken cancellationToken = default)
    {
        var dataPoints = new List<AnalyticsDataPoint>();

        // Get all document packages in the date range
        var packages = await _context.DocumentPackages
            .Include(p => p.ConfidenceScore)
            .Include(p => p.Recommendation)
            .Where(p => p.CreatedAt >= startDate && p.CreatedAt < endDate.AddDays(1))
            .ToListAsync(cancellationToken);

        if (!packages.Any())
        {
            return dataPoints;
        }

        // Group by state and aggregate (using a placeholder for now - will be enhanced with actual state/location data)
        // NOTE: Future enhancement - Add State/Location field to DocumentPackage entity for geographic analytics.
        // This requires domain model changes and database migration. Currently using "Unknown" as placeholder.
        var stateGroups = packages.GroupBy(p => "Unknown");
        foreach (var stateGroup in stateGroups)
        {
            var state = stateGroup.Key;
            var statePackages = stateGroup.ToList();

            var approvedCount = statePackages.Count(p => p.State == PackageState.Approved);
            var rejectedCount = statePackages.Count(p => p.State == PackageState.ASMRejected || p.State == PackageState.RARejected);
            var totalCount = statePackages.Count;

            var avgConfidence = statePackages
                .Where(p => p.ConfidenceScore != null)
                .Average(p => p.ConfidenceScore!.OverallConfidence);

            var avgProcessingTime = statePackages
                .Where(p => p.UpdatedAt.HasValue)
                .Average(p => (p.UpdatedAt!.Value - p.CreatedAt).TotalHours);

            var autoApprovalCount = statePackages
                .Count(p => p.Recommendation?.Type == RecommendationType.Approve && 
                           p.State == PackageState.Approved);

            dataPoints.Add(new AnalyticsDataPoint
            {
                Id = $"{state}_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}",
                State = state,
                Campaign = null, // Will be enhanced in future iterations
                StartDate = startDate,
                EndDate = endDate,
                SubmissionCount = totalCount,
                ApprovedCount = approvedCount,
                RejectedCount = rejectedCount,
                ApprovalRate = totalCount > 0 ? (double)approvedCount / totalCount : 0,
                AvgConfidenceScore = avgConfidence,
                AvgProcessingTimeHours = avgProcessingTime,
                AutoApprovalCount = autoApprovalCount
            });
        }

        // Also create an overall aggregate (all states)
        var allApprovedCount = packages.Count(p => p.State == PackageState.Approved);
        var allRejectedCount = packages.Count(p => p.State == PackageState.ASMRejected || p.State == PackageState.RARejected);
        var allTotalCount = packages.Count;

        var allAvgConfidence = packages
            .Where(p => p.ConfidenceScore != null)
            .Average(p => p.ConfidenceScore!.OverallConfidence);

        var allAvgProcessingTime = packages
            .Where(p => p.UpdatedAt.HasValue)
            .Average(p => (p.UpdatedAt!.Value - p.CreatedAt).TotalHours);

        var allAutoApprovalCount = packages
            .Count(p => p.Recommendation?.Type == RecommendationType.Approve && 
                       p.State == PackageState.Approved);

        dataPoints.Add(new AnalyticsDataPoint
        {
            Id = $"ALL_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}",
            State = null,
            Campaign = null,
            StartDate = startDate,
            EndDate = endDate,
            SubmissionCount = allTotalCount,
            ApprovedCount = allApprovedCount,
            RejectedCount = allRejectedCount,
            ApprovalRate = allTotalCount > 0 ? (double)allApprovedCount / allTotalCount : 0,
            AvgConfidenceScore = allAvgConfidence,
            AvgProcessingTimeHours = allAvgProcessingTime,
            AutoApprovalCount = allAutoApprovalCount
        });

        return dataPoints;
    }

    public async Task<List<VectorDocument>> GenerateVectorDocumentsAsync(
        List<AnalyticsDataPoint> dataPoints,
        CancellationToken cancellationToken = default)
    {
        var vectorDocuments = new List<VectorDocument>();

        // Generate natural language descriptions for each data point
        var descriptions = dataPoints.Select(dp => GenerateDescription(dp)).ToList();

        // Generate embeddings in batch
        var embeddings = await _embeddingService.GenerateEmbeddingsAsync(descriptions, cancellationToken);

        // Create vector documents
        for (int i = 0; i < dataPoints.Count; i++)
        {
            var dataPoint = dataPoints[i];
            var description = descriptions[i];
            var embedding = embeddings[i];

            vectorDocuments.Add(new VectorDocument
            {
                Id = dataPoint.Id,
                Content = description,
                ContentVector = embedding,
                Metadata = new VectorMetadata
                {
                    State = dataPoint.State,
                    TimeRange = $"{dataPoint.StartDate:yyyy-MM-dd} to {dataPoint.EndDate:yyyy-MM-dd}",
                    SubmissionCount = dataPoint.SubmissionCount,
                    ApprovalRate = dataPoint.ApprovalRate,
                    AvgConfidence = dataPoint.AvgConfidenceScore,
                    Campaigns = dataPoint.Campaign != null ? new List<string> { dataPoint.Campaign } : null
                }
            });
        }

        return vectorDocuments;
    }

    private string GenerateDescription(AnalyticsDataPoint dataPoint)
    {
        var stateText = dataPoint.State ?? "All states";
        var dateRange = $"{dataPoint.StartDate:MMMM dd, yyyy} to {dataPoint.EndDate:MMMM dd, yyyy}";
        var approvalRatePercent = (dataPoint.ApprovalRate * 100).ToString("F1");
        var confidenceScore = dataPoint.AvgConfidenceScore.ToString("F1");
        var processingTime = dataPoint.AvgProcessingTimeHours.ToString("F1");
        var autoApprovalRate = dataPoint.SubmissionCount > 0 
            ? ((double)dataPoint.AutoApprovalCount / dataPoint.SubmissionCount * 100).ToString("F1") 
            : "0.0";

        return $"{stateText} had {dataPoint.SubmissionCount} submissions from {dateRange} " +
               $"with {approvalRatePercent}% approval rate. " +
               $"Average confidence score was {confidenceScore} and average processing time was {processingTime} hours. " +
               $"{dataPoint.ApprovedCount} packages were approved, {dataPoint.RejectedCount} were rejected. " +
               $"Auto-approval rate was {autoApprovalRate}% ({dataPoint.AutoApprovalCount} packages).";
    }
}
