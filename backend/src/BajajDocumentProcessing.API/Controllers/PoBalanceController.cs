using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Exposes the real-time PO balance endpoint backed by the SAP PO_Data API.
/// </summary>
[ApiController]
[Route("api/po-balance")]
[Authorize(Roles = "ASM,HQ")]
public class PoBalanceController : ControllerBase
{
    private readonly IPoBalanceService _poBalanceService;
    private readonly ILogger<PoBalanceController> _logger;

    public PoBalanceController(
        IPoBalanceService poBalanceService,
        ILogger<PoBalanceController> logger)
    {
        _poBalanceService = poBalanceService;
        _logger = logger;
    }

    /// <summary>
    /// Returns the calculated PO balance for the given company code and PO number.
    /// Calls the SAP PO_Data API and computes:
    /// Balance = Sum(po_line_item.price_without_tax) - Sum(gr_data.invoice_value)
    /// </summary>
    /// <param name="poNum">SAP Purchase Order number (e.g. 5110014001).</param>
    /// <param name="companyCode">SAP company code (e.g. BAL). Defaults to "BAL".</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    [HttpGet("{poNum}")]
    public async Task<IActionResult> GetPoBalance(
        [FromRoute] string poNum,
        [FromQuery] string companyCode = "BAL",
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(poNum))
            return BadRequest(new { error = "poNum is required." });

        if (string.IsNullOrWhiteSpace(companyCode))
            return BadRequest(new { error = "companyCode is required." });

        try
        {
            var result = await _poBalanceService.GetPoBalanceAsync(companyCode, poNum, cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "SAP error for PO {PoNum}", poNum);
            return StatusCode(502, new ErrorResponse
            {
                CorrelationId = HttpContext.TraceIdentifier,
                Message = ex.Message,
                StatusCode = 502,
                Timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error for PO {PoNum}", poNum);
            return StatusCode(500, new ErrorResponse
            {
                CorrelationId = HttpContext.TraceIdentifier,
                Message = "An unexpected error occurred while calculating the PO balance.",
                StatusCode = 500,
                Timestamp = DateTime.UtcNow
            });
        }
    }
}
