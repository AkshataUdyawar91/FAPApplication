using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Analytics;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Null implementation of IAnalyticsAgent when Azure AI Search is not configured
/// </summary>
public class NullAnalyticsAgent : IAnalyticsAgent
{
    private readonly ILogger<NullAnalyticsAgent> _logger;

    public NullAnalyticsAgent(ILogger<NullAnalyticsAgent> logger)
    {
        _logger = logger;
        _logger.LogWarning("Azure AI Search is not configured. Advanced analytics features are disabled.");
    }

    public Task<KPIDashboard> GetKPIsAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("KPI retrieval skipped - Azure AI Search not configured");
        return Task.FromResult(new KPIDashboard
        {
            StartDate = startDate,
            EndDate = endDate
        });
    }

    public Task<List<StateROI>> GetStateROIAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("State ROI retrieval skipped - Azure AI Search not configured");
        return Task.FromResult(new List<StateROI>());
    }

    public Task<List<CampaignBreakdown>> GetCampaignBreakdownAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Campaign breakdown retrieval skipped - Azure AI Search not configured");
        return Task.FromResult(new List<CampaignBreakdown>());
    }

    public Task<byte[]> ExportToExcelAsync(DateTime startDate, DateTime endDate, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Excel export skipped - Azure AI Search not configured");
        return Task.FromResult(Array.Empty<byte>());
    }

    public Task<string> GenerateNarrativeAsync(KPIDashboard kpis, CancellationToken cancellationToken = default)
    {
        _logger.LogWarning("Analytics narrative generation called but Azure AI Search is not configured");
        
        // Return a basic message indicating the feature is not available
        return Task.FromResult(
            "Advanced analytics with AI-generated narratives is not available. " +
            "Configure Azure AI Search to enable this feature.");
    }

    public Task<QuarterlyFapKpiResponse> GetQuarterlyFapKpisAsync(string quarter, int year, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Quarterly FAP KPI retrieval skipped - Azure AI Search not configured");
        return Task.FromResult(new QuarterlyFapKpiResponse
        {
            Quarter = quarter,
            Year = year,
            FapAmount = 0,
            FapCount = 0
        });
    }
}
