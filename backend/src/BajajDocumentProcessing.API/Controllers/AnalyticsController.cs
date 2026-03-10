using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Analytics;
using BajajDocumentProcessing.Application.DTOs.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Analytics controller for RA dashboard data, KPIs, and reporting
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
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
    [HttpGet("kpis")]
    [Authorize(Roles = "HQ")]
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
    [HttpGet("state-roi")]
    [Authorize(Roles = "HQ")]
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
    [HttpGet("campaign-breakdown")]
    [Authorize(Roles = "HQ")]
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
    [HttpPost("export")]
    [Authorize(Roles = "HQ")]
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
    [HttpPost("narrative")]
    [Authorize(Roles = "HQ")]
    public async Task<IActionResult> GenerateNarrative(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
        var end = endDate ?? DateTime.UtcNow;

        var kpis = await _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);
        var narrative = await _analyticsAgent.GenerateNarrativeAsync(kpis, cancellationToken);

        return Ok(new NarrativeResponse
        {
            Narrative = narrative,
            GeneratedAt = DateTime.UtcNow
        });
    }

    /// <summary>
    /// Get complete dashboard data including KPIs, state ROI, campaign breakdowns, and optional AI narrative
    /// </summary>
    [HttpGet("dashboard")]
    [Authorize(Roles = "HQ")]
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

            var kpisTask = _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);
            var stateRoiTask = _analyticsAgent.GetStateROIAsync(start, end, cancellationToken);
            var campaignBreakdownTask = _analyticsAgent.GetCampaignBreakdownAsync(start, end, cancellationToken);

            await Task.WhenAll(kpisTask, stateRoiTask, campaignBreakdownTask);

            var kpis = await kpisTask;
            var stateRoi = await stateRoiTask;
            var campaignBreakdown = await campaignBreakdownTask;

            string? narrative = null;
            if (includeNarrative)
            {
                narrative = await _analyticsAgent.GenerateNarrativeAsync(kpis, cancellationToken);
            }

            var response = new DashboardDataResponse
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

    /// <summary>
    /// Get quarterly FAP (Final Approved Payment) KPI data
    /// </summary>
    [HttpGet("quarterly-fap")]
    [Authorize(Roles = "ASM,HQ")]
    public async Task<IActionResult> GetQuarterlyFapKpis(
        [FromQuery] string quarter = "current",
        [FromQuery] int? year = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var currentYear = DateTime.UtcNow.Year;
            var resolvedYear = year ?? currentYear;

            if (string.Equals(quarter, "current", StringComparison.OrdinalIgnoreCase))
            {
                quarter = $"Q{(DateTime.UtcNow.Month - 1) / 3 + 1}";
            }

            var validQuarters = new[] { "Q1", "Q2", "Q3", "Q4", "All" };
            if (!validQuarters.Contains(quarter, StringComparer.OrdinalIgnoreCase))
            {
                return BadRequest(new { error = "Invalid quarter. Use Q1, Q2, Q3, Q4, or All." });
            }

            if (resolvedYear < 2000 || resolvedYear > currentYear + 1)
            {
                return BadRequest(new { error = "Invalid year." });
            }

            quarter = quarter.ToUpperInvariant() == "ALL" ? "All" : quarter.ToUpperInvariant();

            var result = await _analyticsAgent.GetQuarterlyFapKpisAsync(quarter, resolvedYear, cancellationToken);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving quarterly FAP KPIs");
            return StatusCode(500, new { error = "An error occurred while retrieving quarterly KPIs" });
        }
    }

    private static List<KpiMetricDto> MapKpisToDtos(KPIDashboard kpis)
    {
        return new List<KpiMetricDto>
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

    private static List<StateRoiDto> MapStateRoiToDtos(List<StateROI> stateRoi)
    {
        return stateRoi.Select(s => new StateRoiDto
        {
            State = s.State,
            SubmissionCount = s.SubmissionCount,
            ApprovedAmount = (decimal)s.ROI * 1000,
            ApprovalRate = (decimal)s.ApprovalRate,
            AvgProcessingTime = 0,
            Roi = (decimal)s.ROI
        }).ToList();
    }

    private static List<CampaignBreakdownDto> MapCampaignBreakdownToDtos(List<CampaignBreakdown> campaigns)
    {
        return campaigns.Select(c => new CampaignBreakdownDto
        {
            CampaignName = c.Campaign,
            SubmissionCount = c.SubmissionCount,
            ApprovedCount = c.ApprovedCount,
            RejectedCount = c.SubmissionCount - c.ApprovedCount,
            PendingCount = 0,
            ApprovalRate = (decimal)c.ApprovalRate,
            TotalAmount = 0
        }).ToList();
    }
}
