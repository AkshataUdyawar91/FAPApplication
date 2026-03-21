using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin read-only view of all Supplier POs.</summary>
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

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPOs(
        [FromQuery] int pageNumber   = 1,
        [FromQuery] int pageSize     = 20,
        [FromQuery] string? search   = null,
        [FromQuery] string? poStatus = null,
        [FromQuery] string? sortBy   = "createdAt",
        [FromQuery] bool sortAsc     = false,
        CancellationToken ct = default)
    {
        try
        {
            pageNumber = Math.Max(1, pageNumber);
            pageSize   = Math.Clamp(pageSize, 1, 100);

            var query = _context.POs
                .AsNoTracking()
                .IgnoreQueryFilters()
                .Where(p => !p.IsDeleted)
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

            // Sorting
            query = sortBy?.ToLower() switch
            {
                "ponumber"         => sortAsc ? query.OrderBy(p => p.PONumber)         : query.OrderByDescending(p => p.PONumber),
                "vendorname"       => sortAsc ? query.OrderBy(p => p.VendorName)       : query.OrderByDescending(p => p.VendorName),
                "totalamount"      => sortAsc ? query.OrderBy(p => p.TotalAmount)      : query.OrderByDescending(p => p.TotalAmount),
                "remainingbalance" => sortAsc ? query.OrderBy(p => p.RemainingBalance) : query.OrderByDescending(p => p.RemainingBalance),
                "podate"           => sortAsc ? query.OrderBy(p => p.PODate)           : query.OrderByDescending(p => p.PODate),
                "postatus"         => sortAsc ? query.OrderBy(p => p.POStatus)         : query.OrderByDescending(p => p.POStatus),
                _                  => sortAsc ? query.OrderBy(p => p.CreatedAt)        : query.OrderByDescending(p => p.CreatedAt),
            };

            var total   = await query.CountAsync(ct);
            var poItems = await query
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(p => new
                {
                    p.Id, p.PONumber, p.VendorName, p.VendorCode,
                    p.TotalAmount, p.RemainingBalance, p.PODate,
                    p.POStatus, p.CreatedAt, p.AgencyId,
                })
                .ToListAsync(ct);

            // Load agency names separately to avoid join issues
            var agencyIds = poItems.Select(p => p.AgencyId).Distinct().ToList();
            var agencies  = await _context.Agencies
                .AsNoTracking()
                .IgnoreQueryFilters()
                .Where(a => agencyIds.Contains(a.Id))
                .Select(a => new { a.Id, a.SupplierName, a.SupplierCode })
                .ToDictionaryAsync(a => a.Id, ct);

            var items = poItems.Select(p => new
            {
                p.Id, p.PONumber, p.VendorName, p.VendorCode,
                p.TotalAmount, p.RemainingBalance, p.PODate, p.POStatus, p.CreatedAt,
                AgencyName = agencies.TryGetValue(p.AgencyId, out var ag)  ? ag.SupplierName : null,
                AgencyCode = agencies.TryGetValue(p.AgencyId, out var ag2) ? ag2.SupplierCode : null,
            }).ToList();

            return Ok(new
            {
                items,
                totalCount = total,
                pageNumber,
                pageSize,
                totalPages = (int)Math.Ceiling((double)total / pageSize),
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching admin POs");
            return StatusCode(500, new { message = ex.Message });
        }
    }
}
