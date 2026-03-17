using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// POs controller — provides lookup endpoints for Purchase Orders and reference data
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class POsController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<POsController> _logger;

    public POsController(IApplicationDbContext context, ILogger<POsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// List POs available to the current agency user, with optional search by PO number or vendor name.
    /// Agency users see only their own agency's POs; ASM/HQ see all.
    /// </summary>
    /// <param name="search">Optional search term matched against PO number or vendor name</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of matching POs with id, poNumber, vendorName, totalAmount, poDate</returns>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ListPOs(
        [FromQuery] string? search = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
                return Unauthorized(new { error = "User ID not found in token" });

            var userId = Guid.Parse(userIdClaim);
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

            var query = _context.POs
                .Include(p => p.Agency)
                .AsNoTracking()
                .AsQueryable();

            // Agency users see only their own agency's POs
            if (userRole == "Agency")
            {
                var user = await _context.Users
                    .AsNoTracking()
                    .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

                if (user?.AgencyId != null)
                    query = query.Where(p => p.AgencyId == user.AgencyId);
                else
                    query = query.Where(p => false); // no agency linked — return empty
            }

            // Search filter
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(p =>
                    (p.PONumber != null && p.PONumber.ToLower().Contains(term)) ||
                    (p.VendorName != null && p.VendorName.ToLower().Contains(term)));
            }

            var pos = await query
                .OrderByDescending(p => p.CreatedAt)
                .Take(50)
                .Select(p => new
                {
                    p.Id,
                    p.PackageId,
                    p.PONumber,
                    p.VendorName,
                    p.TotalAmount,
                    p.PODate,
                    p.FileName,
                    AgencyName = p.Agency != null ? p.Agency.SupplierName : null
                })
                .ToListAsync(cancellationToken);

            return Ok(pos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing POs");
            return StatusCode(500, new { error = "An error occurred while listing POs" });
        }
    }

    /// <summary>
    /// Returns all active Indian states from the StateGstMaster reference table.
    /// Used to populate the Activation State dropdown on the upload form.
    /// </summary>
    [HttpGet("states")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetIndianStates(CancellationToken cancellationToken = default)
    {
        try
        {
            var states = await _context.StateGstMasters
                .AsNoTracking()
                .Where(s => s.IsActive)
                .OrderBy(s => s.StateName)
                .Select(s => new { s.GstCode, s.StateCode, s.StateName })
                .ToListAsync(cancellationToken);

            return Ok(states);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Indian states");
            return StatusCode(500, new { error = "An error occurred while fetching states" });
        }
    }
}
