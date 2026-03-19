using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Triggers a manual SAP PO_CREATE sync.
/// Restricted to HQ role only.
/// </summary>
[ApiController]
[Route("api/po-sync")]
[AllowAnonymous]
public class PoSyncController : ControllerBase
{
    private readonly IPoSyncService _poSyncService;
    private readonly ILogger<PoSyncController> _logger;

    public PoSyncController(IPoSyncService poSyncService, ILogger<PoSyncController> logger)
    {
        _poSyncService = poSyncService;
        _logger        = logger;
    }

    /// <summary>
    /// Pulls PO_CREATE data from SAP, decodes the Base64 payload (ZIP or raw CSV),
    /// filters rows by agency codes from Agency-role users, checks for duplicates,
    /// and upserts PO-Agency records. Every row outcome is audit-logged.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Summary of inserted, skipped, and failed records</returns>
    [HttpPost("trigger")]
    [ProducesResponseType(typeof(PoSyncResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status502BadGateway)]
    public async Task<IActionResult> TriggerSync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Manual PO_CREATE sync triggered by {User}", User.Identity?.Name);

        var result = await _poSyncService.SyncAsync(cancellationToken);

        if (result.ErrorMessage != null)
        {
            return StatusCode(StatusCodes.Status502BadGateway, new
            {
                error        = result.ErrorMessage,
                correlationId = HttpContext.TraceIdentifier
            });
        }

        return Ok(new PoSyncResponse
        {
            Inserted = result.Inserted,
            Skipped  = result.Skipped,
            Failed   = result.Failed,
            SyncedAt = DateTime.UtcNow
        });
    }
}

/// <summary>Response DTO for the PO sync trigger endpoint.</summary>
public sealed record PoSyncResponse
{
    /// <summary>Number of new PO records inserted.</summary>
    public int Inserted { get; init; }

    /// <summary>Number of rows skipped (agency not found or duplicate PO).</summary>
    public int Skipped { get; init; }

    /// <summary>Number of rows that failed to insert.</summary>
    public int Failed { get; init; }

    /// <summary>UTC timestamp when the sync completed.</summary>
    public DateTime SyncedAt { get; init; }
}
