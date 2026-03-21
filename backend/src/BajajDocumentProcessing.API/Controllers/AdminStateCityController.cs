using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin CRUD for State/City master data.</summary>
[ApiController]
[Route("api/admin/state-cities")]
[Authorize(Roles = "Admin")]
public class AdminStateCityController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AdminStateCityController> _logger;

    public AdminStateCityController(IApplicationDbContext context, ILogger<AdminStateCityController> logger)
    {
        _context = context;
        _logger  = logger;
    }

    /// <summary>Get paginated state/city records with optional search and state filter.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int pageNumber    = 1,
        [FromQuery] int pageSize      = 20,
        [FromQuery] string? search    = null,
        [FromQuery] string? stateFilter = null,
        CancellationToken ct = default)
    {
        try
        {
            pageNumber = Math.Max(1, pageNumber);
            pageSize   = Math.Clamp(pageSize, 1, 100);

            var query = _context.StateCities
                .AsNoTracking()
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim().ToLower();
                query = query.Where(x =>
                    x.State.ToLower().Contains(s) ||
                    x.City.ToLower().Contains(s));
            }

            if (!string.IsNullOrWhiteSpace(stateFilter))
                query = query.Where(x => x.State == stateFilter);

            var total = await query.CountAsync(ct);
            var items = await query
                .OrderBy(x => x.State).ThenBy(x => x.City)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(x => new { x.Id, x.State, x.City, x.IsActive, x.CreatedAt })
                .ToListAsync(ct);

            // Distinct states for filter dropdown
            var states = await _context.StateCities
                .AsNoTracking()
                .Select(s => s.State)
                .Distinct()
                .OrderBy(s => s)
                .ToListAsync(ct);

            return Ok(new { items, totalCount = total, pageNumber, pageSize,
                totalPages = (int)Math.Ceiling((double)total / pageSize), states });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching state cities");
            return StatusCode(500, new { message = ex.Message });
        }
    }

    /// <summary>Create a new state/city record.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] StateCityRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.State) || string.IsNullOrWhiteSpace(request.City))
            return BadRequest(new { message = "State and City are required." });

        var exists = await _context.StateCities
            .AnyAsync(s => s.State == request.State.Trim() && s.City == request.City.Trim(), ct);
        if (exists) return Conflict(new { message = "This State/City combination already exists." });

        var entity = new StateCity
        {
            Id        = Guid.NewGuid(),
            State     = request.State.Trim(),
            City      = request.City.Trim(),
            IsActive  = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        _context.StateCities.Add(entity);
        await _context.SaveChangesAsync(ct);
        _logger.LogInformation("Admin created StateCity {State}/{City}", entity.State, entity.City);
        return Ok(new { entity.Id, entity.State, entity.City, entity.IsActive, entity.CreatedAt });
    }

    /// <summary>Update an existing state/city record.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] StateCityRequest request, CancellationToken ct)
    {
        var entity = await _context.StateCities
            .FirstOrDefaultAsync(s => s.Id == id, ct);
        if (entity == null) return NotFound();

        entity.State     = request.State.Trim();
        entity.City      = request.City.Trim();
        entity.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);
        return Ok(new { entity.Id, entity.State, entity.City, entity.IsActive, entity.CreatedAt });
    }

    /// <summary>Hard-delete a state/city record.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id, CancellationToken ct)
    {
        var entity = await _context.StateCities
            .FirstOrDefaultAsync(s => s.Id == id, ct);
        if (entity == null) return NotFound();

        _context.StateCities.Remove(entity);
        await _context.SaveChangesAsync(ct);
        return NoContent();
    }
}

public record StateCityRequest(string State, string City);
