using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin read-only view of all Supplier POs (as-is from SAP/submissions).</summary>
[ApiController]
[Route("api/admin/pos")]
[Authorize(Roles = "Admin")]
public class AdminPOsController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AdminPOsController> _logger;

    public AdminPOsController(IApplicationDbContext context, ILogger<AdminPOsController> logger)
    {
        _context = context;
        _logger  = logger;
    }

    /// <summary>Get paginated list of all POs across all agencies.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPOs(
        [FromQuery] int pageNumber    = 1,
        [FromQuery] int pageSize      = 20,
        [FromQuery] string? search    = null,
        [FromQuery] string? poStatus  = null,
        CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.POs
            .Include(p => p.Agency)
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(p =>
                (p.PONumber != null && p.PONumber.ToLower().Contains(s)) ||
                (p.VendorName != null && p.VendorName.ToLower().Contains(s)));
        }

        if (!string.IsNullOrWhiteSpace(poStatus))
            query = query.Where(p => p.POStatus == poStatus);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(p => p.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(p => new
            {
                p.Id,
                p.PONumber,
                p.VendorName,
                p.VendorCode,
                p.TotalAmount,
                p.RemainingBalance,
                p.PODate,
                p.POStatus,
                p.CreatedAt,
                AgencyName = p.Agency != null ? p.Agency.SupplierName : null,
                AgencyCode = p.Agency != null ? p.Agency.SupplierCode : null,
            })
            .ToListAsync(ct);

        return Ok(new
        {
            items,
            totalCount = total,
            pageNumber,
            pageSize,
            totalPages = (int)Math.Ceiling((double)total / pageSize),
        });
    }
}
