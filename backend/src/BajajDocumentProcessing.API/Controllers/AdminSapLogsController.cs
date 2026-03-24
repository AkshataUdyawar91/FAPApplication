using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin read-only endpoints for SAP log tables.</summary>
[ApiController]
[Route("api/admin/sap-logs")]
[Authorize(Roles = "Admin")]
public class AdminSapLogsController : ControllerBase
{
    private readonly IApplicationDbContext _context;

    public AdminSapLogsController(IApplicationDbContext context) => _context = context;

    // ── PO Balance Logs ──────────────────────────────────────────────────────

    /// <summary>Paginated PO Balance call audit logs.</summary>
    [HttpGet("po-balance")]
    public async Task<IActionResult> GetPoBalanceLogs(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize   = 10,
        [FromQuery] string? search = null,
        [FromQuery] bool? success  = null,
        CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.POBalanceLogs.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(x => x.PoNum.ToLower().Contains(s) ||
                                     x.CompanyCode.ToLower().Contains(s));
        }
        if (success.HasValue)
            query = query.Where(x => x.IsSuccess == success.Value);

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(x => x.RequestedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new
            {
                x.Id,
                x.PoNum,
                x.CompanyCode,
                x.RequestedBy,
                x.RequestedAt,
                x.SapHttpStatus,
                x.Balance,
                x.Currency,
                x.IsSuccess,
                x.ErrorMessage,
                x.ElapsedMs,
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

    // ── PO Sync Logs ─────────────────────────────────────────────────────────

    /// <summary>Paginated PO sync-from-SAP audit logs.</summary>
    [HttpGet("po-sync")]
    public async Task<IActionResult> GetPoSyncLogs(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize   = 10,
        [FromQuery] string? search = null,
        [FromQuery] string? status = null,
        CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.POSyncLogs
            .AsNoTracking()
            .IgnoreQueryFilters()
            .Where(x => !x.IsDeleted)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(x => x.FileName.ToLower().Contains(s));
        }
        if (!string.IsNullOrWhiteSpace(status))
            query = query.Where(x => x.Status == status);

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(x => x.ProcessedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new
            {
                x.Id,
                x.SourceSystem,
                x.FileName,
                x.AgencyId,
                x.POId,
                x.Status,
                x.ErrorMessage,
                x.ProcessedAt,
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
