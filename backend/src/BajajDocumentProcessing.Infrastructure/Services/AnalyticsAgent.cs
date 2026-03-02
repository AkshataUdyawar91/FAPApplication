using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class AnalyticsAgent : IAnalyticsAgent
{
    private readonly IApplicationDbContext _context;
    private readonly IMemoryCache _cache;
    private readonly ILogger<AnalyticsAgent> _logger;
    private readonly Kernel _kernel;
    private const string CacheKeyPrefix = "analytics_";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public AnalyticsAgent(
        IApplicationDbContext context,
        IMemoryCache cache,
        IConfiguration configuration,
        ILogger<AnalyticsAgent> logger)
    {
        _context = context;
        _cache = cache;
        _logger = logger;

        // Build Semantic Kernel for narrative generation
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        _kernel = builder.Build();
    }

    public async Task<KPIDashboard> GetKPIsAsync(
        DateTime startDate,
        DateTime endDate,
        CancellationToken cancellationToken = default)
    {
        var cacheKey = $"{CacheKeyPrefix}kpis_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}";
        
        if (_cache.TryGetValue<KPIDashboard>(cacheKey, out var cachedKpis) && cachedKpis != null)
        {
            _logger.LogDebug("Returning cached KPIs");
            return cachedKpis;
        }

        _logger.LogInformation("Calculating KPIs for period {StartDate} to {EndDate}", startDate, endDate);

        var packages = await _context.DocumentPackages
            .Include(p => p.ConfidenceScore)
            .Include(p => p.Recommendation)
            .Where(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate)
            .ToListAsync(cancellationToken);

        var totalSubmissions = packages.Count;
        var approvedCount = packages.Count(p => p.State == PackageState.Approved);
        var rejectedCount = packages.Count(p => p.State == PackageState.Rejected);
        var pendingCount = packages.Count(p => 
            p.State == PackageState.PendingApproval || 
            p.State == PackageState.Uploaded ||
            p.State == PackageState.Extracting ||
            p.State == PackageState.Validating ||
            p.State == PackageState.Scoring ||
            p.State == PackageState.Recommending);

        var approvalRate = totalSubmissions > 0 ? (double)approvedCount / totalSubmissions * 100 : 0;

        var avgProcessingTime = packages
            .Where(p => p.UpdatedAt.HasValue && (p.State == PackageState.Approved || p.State == PackageState.Rejected))
            .Select(p => (p.UpdatedAt!.Value - p.CreatedAt).TotalHours)
            .DefaultIfEmpty(0)
            .Average();

        var autoApprovalCount = packages
            .Count(p => p.Recommendation?.Type == RecommendationType.Approve && p.State == PackageState.Approved);
        
        var autoApprovalRate = totalSubmissions > 0 ? (double)autoApprovalCount / totalSubmissions * 100 : 0;

        var avgConfidence = packages
            .Where(p => p.ConfidenceScore != null)
            .Select(p => p.ConfidenceScore!.OverallConfidence)
            .DefaultIfEmpty(0)
            .Average();

        // Confidence distribution
        var confidenceDistribution = new Dictionary<string, int>
        {
            { "0-50", packages.Count(p => p.ConfidenceScore != null && p.ConfidenceScore.OverallConfidence < 50) },
            { "50-70", packages.Count(p => p.ConfidenceScore != null && p.ConfidenceScore.OverallConfidence >= 50 && p.ConfidenceScore.OverallConfidence < 70) },
            { "70-85", packages.Count(p => p.ConfidenceScore != null && p.ConfidenceScore.OverallConfidence >= 70 && p.ConfidenceScore.OverallConfidence < 85) },
            { "85-100", packages.Count(p => p.ConfidenceScore != null && p.ConfidenceScore.OverallConfidence >= 85) }
        };

        var kpis = new KPIDashboard
        {
            StartDate = startDate,
            EndDate = endDate,
            TotalSubmissions = totalSubmissions,
            ApprovedCount = approvedCount,
            RejectedCount = rejectedCount,
            PendingCount = pendingCount,
            ApprovalRate = approvalRate,
            AvgProcessingTimeHours = avgProcessingTime,
            AutoApprovalCount = autoApprovalCount,
            AutoApprovalRate = autoApprovalRate,
            AvgConfidenceScore = avgConfidence,
            ConfidenceDistribution = confidenceDistribution
        };

        _cache.Set(cacheKey, kpis, CacheDuration);
        _logger.LogInformation("KPIs calculated and cached");

        return kpis;
    }

    public async Task<List<StateROI>> GetStateROIAsync(
        DateTime startDate,
        DateTime endDate,
        CancellationToken cancellationToken = default)
    {
        var cacheKey = $"{CacheKeyPrefix}state_roi_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}";
        
        if (_cache.TryGetValue<List<StateROI>>(cacheKey, out var cachedRoi) && cachedRoi != null)
        {
            _logger.LogDebug("Returning cached state ROI");
            return cachedRoi;
        }

        _logger.LogInformation("Calculating state-level ROI for period {StartDate} to {EndDate}", startDate, endDate);

        // Placeholder implementation - in production, this would use actual state data
        var stateRoi = new List<StateROI>
        {
            new StateROI
            {
                State = "All States",
                SubmissionCount = await _context.DocumentPackages.CountAsync(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate, cancellationToken),
                ApprovedCount = await _context.DocumentPackages.CountAsync(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate && p.State == PackageState.Approved, cancellationToken),
                ApprovalRate = 0,
                AvgConfidenceScore = 0,
                ROI = 0
            }
        };

        // Calculate rates
        foreach (var state in stateRoi)
        {
            state.ApprovalRate = state.SubmissionCount > 0 ? (double)state.ApprovedCount / state.SubmissionCount * 100 : 0;
            state.ROI = state.ApprovedCount * 1000; // Placeholder ROI calculation
        }

        _cache.Set(cacheKey, stateRoi, CacheDuration);
        _logger.LogInformation("State ROI calculated and cached");

        return stateRoi;
    }

    public async Task<List<CampaignBreakdown>> GetCampaignBreakdownAsync(
        DateTime startDate,
        DateTime endDate,
        CancellationToken cancellationToken = default)
    {
        var cacheKey = $"{CacheKeyPrefix}campaign_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}";
        
        if (_cache.TryGetValue<List<CampaignBreakdown>>(cacheKey, out var cachedCampaigns) && cachedCampaigns != null)
        {
            _logger.LogDebug("Returning cached campaign breakdown");
            return cachedCampaigns;
        }

        _logger.LogInformation("Calculating campaign breakdown for period {StartDate} to {EndDate}", startDate, endDate);

        // Placeholder implementation - in production, this would use actual campaign data
        var campaigns = new List<CampaignBreakdown>
        {
            new CampaignBreakdown
            {
                Campaign = "All Campaigns",
                SubmissionCount = await _context.DocumentPackages.CountAsync(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate, cancellationToken),
                ApprovedCount = await _context.DocumentPackages.CountAsync(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate && p.State == PackageState.Approved, cancellationToken),
                ApprovalRate = 0,
                AvgConfidenceScore = 0
            }
        };

        // Calculate rates
        foreach (var campaign in campaigns)
        {
            campaign.ApprovalRate = campaign.SubmissionCount > 0 ? (double)campaign.ApprovedCount / campaign.SubmissionCount * 100 : 0;
        }

        _cache.Set(cacheKey, campaigns, CacheDuration);
        _logger.LogInformation("Campaign breakdown calculated and cached");

        return campaigns;
    }

    public async Task<byte[]> ExportToExcelAsync(
        DateTime startDate,
        DateTime endDate,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Exporting analytics to Excel for period {StartDate} to {EndDate}", startDate, endDate);

        // Get all data
        var kpis = await GetKPIsAsync(startDate, endDate, cancellationToken);
        var stateRoi = await GetStateROIAsync(startDate, endDate, cancellationToken);
        var campaigns = await GetCampaignBreakdownAsync(startDate, endDate, cancellationToken);

        // Placeholder - in production, use EPPlus to generate Excel file
        // For now, return empty byte array
        _logger.LogWarning("Excel export not yet implemented - returning empty file");
        return Array.Empty<byte>();
    }

    public async Task<string> GenerateNarrativeAsync(
        KPIDashboard kpis,
        CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Generating AI narrative for KPIs");

            var prompt = $@"Generate a concise executive summary of the following analytics data for the Bajaj Document Processing System.
Focus on key insights, trends, and actionable recommendations.

Period: {kpis.StartDate:yyyy-MM-dd} to {kpis.EndDate:yyyy-MM-dd}
Total Submissions: {kpis.TotalSubmissions}
Approved: {kpis.ApprovedCount} ({kpis.ApprovalRate:F1}%)
Rejected: {kpis.RejectedCount}
Pending: {kpis.PendingCount}
Average Processing Time: {kpis.AvgProcessingTimeHours:F1} hours
Auto-Approval Rate: {kpis.AutoApprovalRate:F1}%
Average Confidence Score: {kpis.AvgConfidenceScore:F1}

Confidence Distribution:
- 0-50%: {kpis.ConfidenceDistribution.GetValueOrDefault("0-50", 0)} submissions
- 50-70%: {kpis.ConfidenceDistribution.GetValueOrDefault("50-70", 0)} submissions
- 70-85%: {kpis.ConfidenceDistribution.GetValueOrDefault("70-85", 0)} submissions
- 85-100%: {kpis.ConfidenceDistribution.GetValueOrDefault("85-100", 0)} submissions

Provide a 2-3 paragraph summary highlighting the most important insights.";

            var chatService = _kernel.GetRequiredService<IChatCompletionService>();
            var result = await chatService.GetChatMessageContentAsync(prompt, cancellationToken: cancellationToken);

            var narrative = result.Content ?? "Unable to generate narrative at this time.";
            _logger.LogInformation("AI narrative generated successfully");

            return narrative;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating AI narrative");
            return "Error generating narrative. Please review the KPI data directly.";
        }
    }
}
