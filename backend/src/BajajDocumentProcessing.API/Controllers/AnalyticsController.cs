using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Analytics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BajajDocumentProcessing.API.Controllers;

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
    /// Get KPI dashboard data
    /// </summary>
    [HttpGet("kpis")]
    [Authorize(Roles = "HQ")]
    public async Task<IActionResult> GetKPIs(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
            var end = endDate ?? DateTime.UtcNow;

            var kpis = await _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);

            return Ok(kpis);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting KPIs");
            return StatusCode(500, new { error = "An error occurred while retrieving KPIs" });
        }
    }

    /// <summary>
    /// Get state-level ROI data
    /// </summary>
    [HttpGet("state-roi")]
    [Authorize(Roles = "HQ")]
    public async Task<IActionResult> GetStateROI(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
            var end = endDate ?? DateTime.UtcNow;

            var stateRoi = await _analyticsAgent.GetStateROIAsync(start, end, cancellationToken);

            return Ok(stateRoi);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting state ROI");
            return StatusCode(500, new { error = "An error occurred while retrieving state ROI" });
        }
    }

    /// <summary>
    /// Get campaign breakdown data
    /// </summary>
    [HttpGet("campaign-breakdown")]
    [Authorize(Roles = "HQ")]
    public async Task<IActionResult> GetCampaignBreakdown(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
            var end = endDate ?? DateTime.UtcNow;

            var campaigns = await _analyticsAgent.GetCampaignBreakdownAsync(start, end, cancellationToken);

            return Ok(campaigns);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting campaign breakdown");
            return StatusCode(500, new { error = "An error occurred while retrieving campaign breakdown" });
        }
    }

    /// <summary>
    /// Export analytics to Excel
    /// </summary>
    [HttpPost("export")]
    [Authorize(Roles = "HQ")]
    public async Task<IActionResult> ExportToExcel(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
            var end = endDate ?? DateTime.UtcNow;

            var excelData = await _analyticsAgent.ExportToExcelAsync(start, end, cancellationToken);

            return File(
                excelData,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"analytics_{start:yyyyMMdd}_{end:yyyyMMdd}.xlsx");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error exporting analytics");
            return StatusCode(500, new { error = "An error occurred while exporting analytics" });
        }
    }

    /// <summary>
    /// Generate AI narrative for KPIs
    /// </summary>
    [HttpPost("narrative")]
    [Authorize(Roles = "HQ")]
    public async Task<IActionResult> GenerateNarrative(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var start = startDate ?? DateTime.UtcNow.AddMonths(-1);
            var end = endDate ?? DateTime.UtcNow;

            var kpis = await _analyticsAgent.GetKPIsAsync(start, end, cancellationToken);
            var narrative = await _analyticsAgent.GenerateNarrativeAsync(kpis, cancellationToken);

            return Ok(new { narrative });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating narrative");
            return StatusCode(500, new { error = "An error occurred while generating narrative" });
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

            // Resolve "current" to actual quarter
            if (string.Equals(quarter, "current", StringComparison.OrdinalIgnoreCase))
            {
                quarter = $"Q{(DateTime.UtcNow.Month - 1) / 3 + 1}";
            }

            // Validate quarter
            var validQuarters = new[] { "Q1", "Q2", "Q3", "Q4", "All" };
            if (!validQuarters.Contains(quarter, StringComparer.OrdinalIgnoreCase))
            {
                return BadRequest(new { error = "Invalid quarter. Use Q1, Q2, Q3, Q4, or All." });
            }

            // Validate year
            if (resolvedYear < 2000 || resolvedYear > currentYear + 1)
            {
                return BadRequest(new { error = "Invalid year." });
            }

            // Normalize quarter casing
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
}
