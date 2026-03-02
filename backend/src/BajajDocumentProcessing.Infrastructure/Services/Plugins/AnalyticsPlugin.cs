using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.SemanticKernel;
using System.ComponentModel;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services.Plugins;

public class AnalyticsPlugin
{
    private readonly IApplicationDbContext _context;
    private readonly IVectorSearchService _vectorSearchService;
    private readonly IEmbeddingService _embeddingService;

    public AnalyticsPlugin(
        IApplicationDbContext context,
        IVectorSearchService vectorSearchService,
        IEmbeddingService embeddingService)
    {
        _context = context;
        _vectorSearchService = vectorSearchService;
        _embeddingService = embeddingService;
    }

    [KernelFunction, Description("Search analytics data semantically using natural language queries")]
    public async Task<string> SearchAnalytics(
        [Description("The natural language query to search for")] string query,
        [Description("Optional state filter")] string? state = null,
        [Description("Optional time range filter")] string? timeRange = null)
    {
        try
        {
            // Generate embedding for the query
            var queryEmbedding = await _embeddingService.GenerateEmbeddingAsync(query);

            // Create filter
            var filter = new VectorSearchFilter
            {
                State = state,
                TimeRange = timeRange
            };

            // Search vector database
            var results = await _vectorSearchService.SearchAsync(queryEmbedding, topK: 5, filter: filter);

            if (!results.Any())
            {
                return "No relevant analytics data found for your query.";
            }

            // Format results
            var formattedResults = results.Select((r, i) => 
                $"{i + 1}. {r.Content} (Relevance: {r.Score:F2})").ToList();

            return string.Join("\n\n", formattedResults);
        }
        catch (Exception ex)
        {
            return $"Error searching analytics: {ex.Message}";
        }
    }

    [KernelFunction, Description("Get key performance indicators (KPIs) for a specific time period")]
    public async Task<string> GetKPIs(
        [Description("Start date in format YYYY-MM-DD")] string? startDate = null,
        [Description("End date in format YYYY-MM-DD")] string? endDate = null)
    {
        try
        {
            var start = string.IsNullOrEmpty(startDate) ? DateTime.UtcNow.AddMonths(-1) : DateTime.Parse(startDate);
            var end = string.IsNullOrEmpty(endDate) ? DateTime.UtcNow : DateTime.Parse(endDate);

            var packages = _context.DocumentPackages
                .Where(p => p.CreatedAt >= start && p.CreatedAt <= end)
                .ToList();

            var totalSubmissions = packages.Count;
            var approvedCount = packages.Count(p => p.State == Domain.Enums.PackageState.Approved);
            var rejectedCount = packages.Count(p => p.State == Domain.Enums.PackageState.Rejected);
            var approvalRate = totalSubmissions > 0 ? (double)approvedCount / totalSubmissions * 100 : 0;

            var avgProcessingTime = packages
                .Where(p => p.UpdatedAt.HasValue)
                .Average(p => (p.UpdatedAt!.Value - p.CreatedAt).TotalHours);

            var avgConfidence = packages
                .Where(p => p.ConfidenceScore != null)
                .Average(p => p.ConfidenceScore!.OverallConfidence);

            var kpis = new
            {
                Period = $"{start:yyyy-MM-dd} to {end:yyyy-MM-dd}",
                TotalSubmissions = totalSubmissions,
                ApprovedCount = approvedCount,
                RejectedCount = rejectedCount,
                ApprovalRate = $"{approvalRate:F1}%",
                AvgProcessingTimeHours = $"{avgProcessingTime:F1}",
                AvgConfidenceScore = $"{avgConfidence:F1}"
            };

            return JsonSerializer.Serialize(kpis, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving KPIs: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get state-level ROI and performance data")]
    public async Task<string> GetStateROI(
        [Description("Optional state name to filter by")] string? state = null)
    {
        try
        {
            // For now, return a placeholder since we don't have state field in DocumentPackage
            // In production, this would query actual state-level data
            var message = string.IsNullOrEmpty(state)
                ? "State-level ROI data is not yet available. The system needs to be enhanced with state/location tracking."
                : $"ROI data for {state} is not yet available. The system needs to be enhanced with state/location tracking.";

            return message;
        }
        catch (Exception ex)
        {
            return $"Error retrieving state ROI: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get campaign performance breakdown")]
    public async Task<string> GetCampaignData(
        [Description("Optional campaign name to filter by")] string? campaignName = null)
    {
        try
        {
            // For now, return a placeholder since we don't have campaign field in DocumentPackage
            // In production, this would query actual campaign data
            var message = string.IsNullOrEmpty(campaignName)
                ? "Campaign performance data is not yet available. The system needs to be enhanced with campaign tracking."
                : $"Performance data for campaign '{campaignName}' is not yet available. The system needs to be enhanced with campaign tracking.";

            return message;
        }
        catch (Exception ex)
        {
            return $"Error retrieving campaign data: {ex.Message}";
        }

        await Task.CompletedTask;
    }
}
