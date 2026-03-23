using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin CRUD for Dealer master data.</summary>
[ApiController]
[Route("api/admin/dealers")]
[Authorize(Roles = "Admin")]
public class AdminDealerController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AdminDealerController> _logger;

    public AdminDealerController(IApplicationDbContext context, ILogger<AdminDealerController> logger)
    {
        _context = context;
        _logger  = logger;
    }

    /// <summary>Get paginated dealers with optional search, state and status filters.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int pageNumber       = 1,
        [FromQuery] int pageSize         = 20,
        [FromQuery] string? search       = null,
        [FromQuery] string? stateFilter  = null,
        [FromQuery] bool?  activeFilter  = null,
        CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.Dealers
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(d =>
                d.DealerCode.ToLower().Contains(s) ||
                d.DealerName.ToLower().Contains(s) ||
                d.State.ToLower().Contains(s) ||
                (d.City != null && d.City.ToLower().Contains(s)));
        }

        if (!string.IsNullOrWhiteSpace(stateFilter))
            query = query.Where(d => d.State == stateFilter);

        if (activeFilter.HasValue)
            query = query.Where(d => d.IsActive == activeFilter.Value);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(d => d.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(d => new
            {
                d.Id, d.DealerCode, d.DealerName,
                d.State, d.City, d.IsActive, d.CreatedAt
            })
            .ToListAsync(ct);

        // Distinct states for filter dropdown
        var states = await _context.Dealers
            .AsNoTracking()
            .Select(d => d.State)
            .Distinct()
            .OrderBy(s => s)
            .ToListAsync(ct);

        return Ok(new
        {
            items,
            totalCount = total,
            pageNumber,
            pageSize,
            totalPages = (int)Math.Ceiling((double)total / pageSize),
            states
        });
    }

    /// <summary>Create a new dealer.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] DealerRequest req, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.DealerCode) || string.IsNullOrWhiteSpace(req.DealerName)
            || string.IsNullOrWhiteSpace(req.State))
            return BadRequest(new { message = "DealerCode, DealerName and State are required." });

        var exists = await _context.Dealers
            .AnyAsync(d => d.DealerCode == req.DealerCode.Trim(), ct);
        if (exists)
            return Conflict(new { message = $"Dealer code '{req.DealerCode}' already exists." });

        var entity = new Dealer
        {
            Id         = Guid.NewGuid(),
            DealerCode = req.DealerCode.Trim().ToUpper(),
            DealerName = req.DealerName.Trim(),
            State      = req.State.Trim(),
            City       = req.City?.Trim(),
            IsActive   = true,
            CreatedAt  = DateTime.UtcNow,
            UpdatedAt  = DateTime.UtcNow,
        };
        _context.Dealers.Add(entity);
        await _context.SaveChangesAsync(ct);
        _logger.LogInformation("Admin created Dealer {Code} - {Name}", entity.DealerCode, entity.DealerName);
        return Ok(new { entity.Id, entity.DealerCode, entity.DealerName, entity.State, entity.City, entity.IsActive, entity.CreatedAt });
    }

    /// <summary>Update dealer — DealerCode is immutable.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] DealerUpdateRequest req, CancellationToken ct)
    {
        var entity = await _context.Dealers
            .FirstOrDefaultAsync(d => d.Id == id, ct);
        if (entity == null) return NotFound();

        entity.DealerName = req.DealerName.Trim();
        entity.State      = req.State.Trim();
        entity.City       = req.City?.Trim();
        entity.IsActive   = req.IsActive;
        entity.UpdatedAt  = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);
        return Ok(new { entity.Id, entity.DealerCode, entity.DealerName, entity.State, entity.City, entity.IsActive, entity.CreatedAt });
    }

    /// <summary>Hard-delete a dealer.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id, CancellationToken ct)
    {
        var entity = await _context.Dealers
            .FirstOrDefaultAsync(d => d.Id == id, ct);
        if (entity == null) return NotFound();

        _context.Dealers.Remove(entity);
        await _context.SaveChangesAsync(ct);
        return NoContent();
    }
}

public record DealerRequest(string DealerCode, string DealerName, string State, string? City);
public record DealerUpdateRequest(string DealerName, string State, string? City, bool IsActive);
