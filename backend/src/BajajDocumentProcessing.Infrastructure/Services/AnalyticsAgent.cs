using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Analytics;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for calculating analytics KPIs and generating AI-powered insights for the dashboard.
/// </summary>
/// <remarks>
/// This service:
/// - Calculates key performance indicators (submission counts, approval rates, processing times)
/// - Provides state-level ROI analysis
/// - Generates campaign breakdowns
/// - Exports analytics data to Excel
/// - Uses Azure OpenAI to generate executive summaries
/// - Implements caching with 5-minute TTL to optimize performance
/// </remarks>
public class AnalyticsAgent : IAnalyticsAgent
{
    private readonly IApplicationDbContext _context;
    private readonly IMemoryCache _cache;
    private readonly ILogger<AnalyticsAgent> _logger;
    private readonly Kernel _kernel;
    private readonly ICorrelationIdService _correlationIdService;
    private const string CacheKeyPrefix = "analytics_";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public AnalyticsAgent(
        IApplicationDbContext context,
        IMemoryCache cache,
        IConfiguration configuration,
        ILogger<AnalyticsAgent> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _cache = cache;
        _logger = logger;
        _correlationIdService = correlationIdService;

        // Build Semantic Kernel for narrative generation
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        _kernel = builder.Build();
    }

    /// <summary>
    /// Retrieves key performance indicators for the specified date range.
    /// </summary>
    /// <param name="startDate">The start date of the reporting period (inclusive).</param>
    /// <param name="endDate">The end date of the reporting period (inclusive).</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A <see cref="KPIDashboard"/> containing all calculated metrics and distributions.</returns>
    /// <remarks>
    /// Calculated metrics include:
    /// - Total submissions, approved, rejected, and pending counts
    /// - Approval rate percentage
    /// - Average processing time in hours
    /// - Auto-approval count and rate
    /// - Average confidence score
    /// - Confidence distribution across ranges (0-50%, 50-70%, 70-85%, 85-100%)
    /// 
    /// Results are cached for 5 minutes to optimize performance.
    /// </remarks>
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

        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Calculating KPIs for period {StartDate} to {EndDate}. CorrelationId: {CorrelationId}",
            startDate, endDate, correlationId);

        var packages = await _context.DocumentPackages
            .Include(p => p.ConfidenceScore)
            .Include(p => p.Recommendation)
            .Where(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate)
            .ToListAsync(cancellationToken);

        var totalSubmissions = packages.Count;
        var approvedCount = packages.Count(p => p.State == PackageState.Approved);
        var rejectedCount = packages.Count(p => p.State == PackageState.CHRejected || p.State == PackageState.RARejected);
        var pendingCount = packages.Count(p => 
            p.State == PackageState.PendingCH || 
            p.State == PackageState.PendingRA ||
            p.State == PackageState.Uploaded ||
            p.State == PackageState.Extracting ||
            p.State == PackageState.Validating);

        var approvalRate = totalSubmissions > 0 ? (double)approvedCount / totalSubmissions * 100 : 0;

        var avgProcessingTime = packages
            .Where(p => p.UpdatedAt.HasValue && (p.State == PackageState.Approved || p.State == PackageState.CHRejected || p.State == PackageState.RARejected))
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
        
        _logger.LogInformation(
            "KPIs calculated and cached. CorrelationId: {CorrelationId}",
            correlationId);

        return kpis;
    }

    /// <summary>
    /// Retrieves state-level return on investment analysis for the specified date range.
    /// </summary>
    /// <param name="startDate">The start date of the reporting period (inclusive).</param>
    /// <param name="endDate">The end date of the reporting period (inclusive).</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A list of <see cref="StateROI"/> objects containing state-level metrics.</returns>
    /// <remarks>
    /// <para><strong>NOTE: This is a placeholder implementation.</strong></para>
    /// <para>
    /// Currently returns aggregated data for "All States". In production, this would:
    /// - Group submissions by state/location
    /// - Calculate per-state submission and approval counts
    /// - Compute approval rates and average confidence scores per state
    /// - Calculate ROI based on approved submission value
    /// </para>
    /// <para>Results are cached for 5 minutes to optimize performance.</para>
    /// </remarks>
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

    /// <summary>
    /// Retrieves campaign-level breakdown of submissions and approvals for the specified date range.
    /// </summary>
    /// <param name="startDate">The start date of the reporting period (inclusive).</param>
    /// <param name="endDate">The end date of the reporting period (inclusive).</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A list of <see cref="CampaignBreakdown"/> objects containing campaign-level metrics.</returns>
    /// <remarks>
    /// <para><strong>NOTE: This is a placeholder implementation.</strong></para>
    /// <para>
    /// Currently returns aggregated data for "All Campaigns". In production, this would:
    /// - Group submissions by campaign identifier
    /// - Calculate per-campaign submission and approval counts
    /// - Compute approval rates and average confidence scores per campaign
    /// - Enable campaign performance comparison
    /// </para>
    /// <para>Results are cached for 5 minutes to optimize performance.</para>
    /// </remarks>
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

    /// <summary>
    /// Exports analytics data to an Excel file for the specified date range.
    /// </summary>
    /// <param name="startDate">The start date of the reporting period (inclusive).</param>
    /// <param name="endDate">The end date of the reporting period (inclusive).</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A byte array containing the Excel file data.</returns>
    /// <remarks>
    /// <para><strong>NOTE: This is a placeholder implementation.</strong></para>
    /// <para>
    /// Currently returns an empty byte array. In production, this would:
    /// - Retrieve KPIs, state ROI, and campaign breakdown data
    /// - Use EPPlus library to generate Excel workbook
    /// - Create separate worksheets for each data category
    /// - Include charts and formatting for executive reporting
    /// - Return the Excel file as a byte array for download
    /// </para>
    /// </remarks>
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

    /// <summary>
    /// Generates an AI-powered executive summary narrative from KPI data using Azure OpenAI.
    /// </summary>
    /// <param name="kpis">The KPI dashboard data to analyze and summarize.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A 2-3 paragraph executive summary highlighting key insights, trends, and actionable recommendations.</returns>
    /// <remarks>
    /// This method:
    /// - Constructs a detailed prompt with all KPI metrics and distributions
    /// - Sends the prompt to Azure OpenAI via Semantic Kernel
    /// - Requests a concise executive summary focusing on insights and recommendations
    /// - Returns a fallback message if AI generation fails
    /// - Generates narratives suitable for executive dashboards and reports
    /// </remarks>
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

    /// <summary>
    /// Get quarterly FAP (Final Approved Payment) KPI data
    /// </summary>
    public async Task<QuarterlyFapKpiResponse> GetQuarterlyFapKpisAsync(
        string quarter,
        int year,
        CancellationToken cancellationToken = default)
    {
        var cacheKey = $"{CacheKeyPrefix}quarterly_fap_{quarter}_{year}";

        if (_cache.TryGetValue<QuarterlyFapKpiResponse>(cacheKey, out var cached) && cached != null)
        {
            _logger.LogDebug("Returning cached quarterly FAP KPIs for {Quarter} {Year}", quarter, year);
            return cached;
        }

        _logger.LogInformation("Calculating quarterly FAP KPIs for {Quarter} {Year}", quarter, year);

        var (startDate, endDate) = GetQuarterDateRange(quarter, year);

        var packages = await _context.DocumentPackages
            .Include(p => p.Invoices)
            .Where(p => p.State == PackageState.Approved)
            .Where(p => p.CreatedAt >= startDate && p.CreatedAt <= endDate)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        decimal fapAmount = 0;
        int fapCount = 0;

        foreach (var package in packages)
        {
            var invoices = package.Invoices.Where(i => !i.IsDeleted).ToList();

            if (invoices.Count == 0)
                continue;

            fapCount++;

            foreach (var invoice in invoices)
            {
                if (invoice.TotalAmount != null && invoice.TotalAmount > 0)
                {
                    fapAmount += invoice.TotalAmount.Value;
                }
                else
                {
                    fapAmount += ExtractTotalAmount(invoice.ExtractedDataJson);
                }
            }
        }

        var response = new QuarterlyFapKpiResponse
        {
            Quarter = quarter,
            Year = year,
            FapAmount = fapAmount,
            FapCount = fapCount
        };

        _cache.Set(cacheKey, response, CacheDuration);
        _logger.LogInformation("Quarterly FAP KPIs calculated: Amount={FapAmount}, Count={FapCount}", fapAmount, fapCount);

        return response;
    }

    /// <summary>
    /// Maps a quarter string and year to a date range
    /// </summary>
    private static (DateTime Start, DateTime End) GetQuarterDateRange(string quarter, int year)
    {
        return quarter.ToUpperInvariant() switch
        {
            "Q1" => (new DateTime(year, 1, 1), new DateTime(year, 3, 31, 23, 59, 59)),
            "Q2" => (new DateTime(year, 4, 1), new DateTime(year, 6, 30, 23, 59, 59)),
            "Q3" => (new DateTime(year, 7, 1), new DateTime(year, 9, 30, 23, 59, 59)),
            "Q4" => (new DateTime(year, 10, 1), new DateTime(year, 12, 31, 23, 59, 59)),
            _ => (new DateTime(year, 1, 1), new DateTime(year, 12, 31, 23, 59, 59)) // "All"
        };
    }

    /// <summary>
    /// Extracts TotalAmount from Invoice ExtractedDataJson. Returns 0 for null or malformed JSON.
    /// </summary>
    private decimal ExtractTotalAmount(string? extractedDataJson)
    {
        if (string.IsNullOrEmpty(extractedDataJson))
            return 0;

        try
        {
            var jsonDoc = JsonDocument.Parse(extractedDataJson);
            if (jsonDoc.RootElement.TryGetProperty("TotalAmount", out var totalAmountElement) ||
                jsonDoc.RootElement.TryGetProperty("totalAmount", out totalAmountElement))
            {
                return totalAmountElement.GetDecimal();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to extract TotalAmount from ExtractedDataJson");
        }

        return 0;
    }
}
