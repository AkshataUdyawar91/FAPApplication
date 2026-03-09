using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Analytics controller for HQ dashboard data, KPIs, and reporting
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "HQ")]
public class AnalyticsController : ControllerBase
{
    private readonly IAnalyticsAgent _analyticsAgent;
    private readonly ILogger<AnalyticsController> _logger;

    public AnalyticsController(
        IAnalyticsAgent analyticsAgent,
        ILogger<AnalyticsController> logger)
    {
        _analyticsAgent = analyticsAgent;
        _logger = logger;
    }

    /// <summary>
    /// Get KPI dashboard data for a specified date range
    /// </summary>
    /// <param name="startDate">Start date for analytics period (defaults to 1 month ago)</param>
    /// <param name="endDate">End date for analytics period (defaults to now)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>KPI metrics including submission counts, approval rates, and processing times</returns>
    /// <response code="200">Returns KPI dashboard data</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("kpis")]
    public async Task<IActionResult> GetKPIs(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
        var end = endDate ?? DateTime.UtcNow;

        var kpis = await _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);

        return Ok(kpis);
    }

    /// <summary>
    /// Get state-level ROI data for geographic analysis
    /// </summary>
    /// <param name="startDate">Start date for analytics period (defaults to 1 month ago)</param>
    /// <param name="endDate">End date for analytics period (defaults to now)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>State-wise ROI metrics including submission counts and approval rates</returns>
    /// <response code="200">Returns state ROI data</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("state-roi")]
    public async Task<IActionResult> GetStateROI(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
        var end = endDate ?? DateTime.UtcNow;

        var stateRoi = await _analyticsAgent.GetStateROIAsync(start, end, cancellationToken);

        return Ok(stateRoi);
    }

    /// <summary>
    /// Get campaign breakdown data showing performance by campaign type
    /// </summary>
    /// <param name="startDate">Start date for analytics period (defaults to 1 month ago)</param>
    /// <param name="endDate">End date for analytics period (defaults to now)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Campaign-wise metrics including submission counts and approval rates</returns>
    /// <response code="200">Returns campaign breakdown data</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("campaign-breakdown")]
    public async Task<IActionResult> GetCampaignBreakdown(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
        var end = endDate ?? DateTime.UtcNow;

        var campaigns = await _analyticsAgent.GetCampaignBreakdownAsync(start, end, cancellationToken);

        return Ok(campaigns);
    }

    /// <summary>
    /// Export analytics data to Excel format for offline analysis
    /// </summary>
    /// <param name="startDate">Start date for analytics period (defaults to 1 month ago)</param>
    /// <param name="endDate">End date for analytics period (defaults to now)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Excel file containing analytics data</returns>
    /// <response code="200">Returns Excel file with analytics data</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="500">Internal server error</response>
    [HttpPost("export")]
    public async Task<IActionResult> ExportToExcel(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
        var end = endDate ?? DateTime.UtcNow;

        var excelData = await _analyticsAgent.ExportToExcelAsync(start, end, cancellationToken);

        return File(
            excelData,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"analytics_{start:yyyyMMdd}_{end:yyyyMMdd}.xlsx");
    }

    /// <summary>
    /// Generate AI-powered narrative summary of KPI data using Azure OpenAI
    /// </summary>
    /// <param name="startDate">Start date for analytics period (defaults to 1 month ago)</param>
    /// <param name="endDate">End date for analytics period (defaults to now)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>AI-generated narrative explaining KPI trends and insights</returns>
    /// <response code="200">Returns AI narrative response</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="500">Internal server error</response>
    [HttpPost("narrative")]
    public async Task<IActionResult> GenerateNarrative(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
        var end = endDate ?? DateTime.UtcNow;

        var kpis = await _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);
        var narrative = await _analyticsAgent.GenerateNarrativeAsync(kpis, cancellationToken);

        return Ok(new Application.DTOs.Analytics.NarrativeResponse
        {
            Narrative = narrative,
            GeneratedAt = DateTime.UtcNow
        });
    }

    /// <summary>
    /// Get complete dashboard data including KPIs, state ROI, campaign breakdowns, and optional AI narrative
    /// </summary>
    /// <param name="startDate">Start date for analytics period (defaults to 1 month ago)</param>
    /// <param name="endDate">End date for analytics period (defaults to now)</param>
    /// <param name="includeNarrative">Whether to include AI-generated narrative (default: false)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Comprehensive dashboard data with all analytics metrics</returns>
    /// <response code="200">Returns complete dashboard data</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        [FromQuery] bool includeNarrative = false,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
            var end = endDate ?? DateTime.UtcNow;

            // Fetch all analytics data in parallel
            var kpisTask = _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);
            var stateRoiTask = _analyticsAgent.GetStateROIAsync(start, end, cancellationToken);
            var campaignBreakdownTask = _analyticsAgent.GetCampaignBreakdownAsync(start, end, cancellationToken);

            await Task.WhenAll(kpisTask, stateRoiTask, campaignBreakdownTask);

            var kpis = await kpisTask;
            var stateRoi = await stateRoiTask;
            var campaignBreakdown = await campaignBreakdownTask;

            // Optionally generate AI narrative
            string? narrative = null;
            if (includeNarrative)
            {
                narrative = await _analyticsAgent.GenerateNarrativeAsync(kpis, cancellationToken);
            }

            // Map domain models to DTOs
            var response = new Application.DTOs.Analytics.DashboardDataResponse
            {
                Kpis = MapKpisToDtos(kpis),
                StateRoi = MapStateRoiToDtos(stateRoi),
                CampaignBreakdown = MapCampaignBreakdownToDtos(campaignBreakdown),
                AiNarrative = narrative,
                GeneratedAt = DateTime.UtcNow
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting dashboard data");
            return StatusCode(500, new ErrorResponse
            {
                CorrelationId = HttpContext.TraceIdentifier,
                Message = "An error occurred while retrieving dashboard data",
                StatusCode = 500,
                Timestamp = DateTime.UtcNow
            });
        }
    }

    private static List<Application.DTOs.Analytics.KpiMetricDto> MapKpisToDtos(KPIDashboard kpis)
    {
        return new List<Application.DTOs.Analytics.KpiMetricDto>
        {
            new() { Name = "Total Submissions", Value = kpis.TotalSubmissions, Unit = "count", Change = null, Trend = null },
            new() { Name = "Approved Count", Value = kpis.ApprovedCount, Unit = "count", Change = null, Trend = null },
            new() { Name = "Rejected Count", Value = kpis.RejectedCount, Unit = "count", Change = null, Trend = null },
            new() { Name = "Pending Count", Value = kpis.PendingCount, Unit = "count", Change = null, Trend = null },
            new() { Name = "Approval Rate", Value = (decimal)kpis.ApprovalRate, Unit = "percentage", Change = null, Trend = null },
            new() { Name = "Avg Processing Time", Value = (decimal)kpis.AvgProcessingTimeHours, Unit = "hours", Change = null, Trend = null },
            new() { Name = "Auto Approval Count", Value = kpis.AutoApprovalCount, Unit = "count", Change = null, Trend = null },
            new() { Name = "Auto Approval Rate", Value = (decimal)kpis.AutoApprovalRate, Unit = "percentage", Change = null, Trend = null },
            new() { Name = "Avg Confidence Score", Value = (decimal)kpis.AvgConfidenceScore, Unit = "score", Change = null, Trend = null }
        };
    }

    private static List<Application.DTOs.Analytics.StateRoiDto> MapStateRoiToDtos(List<StateROI> stateRoi)
    {
        return stateRoi.Select(s => new Application.DTOs.Analytics.StateRoiDto
        {
            State = s.State,
            SubmissionCount = s.SubmissionCount,
            ApprovedAmount = (decimal)s.ROI * 1000, // Placeholder calculation
            ApprovalRate = (decimal)s.ApprovalRate,
            AvgProcessingTime = 0, // Not available in source data
            Roi = (decimal)s.ROI
        }).ToList();
    }

    private static List<Application.DTOs.Analytics.CampaignBreakdownDto> MapCampaignBreakdownToDtos(List<CampaignBreakdown> campaigns)
    {
        return campaigns.Select(c => new Application.DTOs.Analytics.CampaignBreakdownDto
        {
            CampaignName = c.Campaign,
            SubmissionCount = c.SubmissionCount,
            ApprovedCount = c.ApprovedCount,
            RejectedCount = c.SubmissionCount - c.ApprovedCount, // Calculated
            PendingCount = 0, // Not available in source data
            ApprovalRate = (decimal)c.ApprovalRate,
            TotalAmount = 0 // Not available in source data
        }).ToList();
    }
}
