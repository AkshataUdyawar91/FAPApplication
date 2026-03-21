using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin CRUD for RA/CH/State mapping.</summary>
[ApiController]
[Route("api/admin/state-mappings")]
[Authorize(Roles = "Admin")]
public class AdminStateMappingController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AdminStateMappingController> _logger;

    public AdminStateMappingController(IApplicationDbContext context,
        ILogger<AdminStateMappingController> logger)
    {
        _context = context;
        _logger  = logger;
    }

    /// <summary>Get all state mappings with joined CH and RA user names.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int pageNumber   = 1,
        [FromQuery] int pageSize     = 20,
        [FromQuery] string? search   = null,
        CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.StateMappings
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(x => x.State.ToLower().Contains(s));
        }

        var total = await query.CountAsync(ct);

        var rawItems = await query
            .OrderBy(x => x.State)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new
            {
                x.Id, x.State, x.CircleHeadUserId, x.RAUserId, x.IsActive, x.CreatedAt
            })
            .ToListAsync(ct);

        // Resolve user names separately to avoid complex EF join issues
        var userIds = rawItems
            .SelectMany(r => new[] { r.CircleHeadUserId, r.RAUserId })
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        var users = await _context.Users
            .AsNoTracking()
            .IgnoreQueryFilters()
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new { u.Id, u.FullName, u.Email })
            .ToListAsync(ct);

        var userMap = users.ToDictionary(u => u.Id);

        var result = rawItems.Select(r => new
        {
            r.Id,
            r.State,
            r.CircleHeadUserId,
            chName  = r.CircleHeadUserId.HasValue && userMap.ContainsKey(r.CircleHeadUserId.Value)
                        ? userMap[r.CircleHeadUserId.Value].FullName : null,
            chEmail = r.CircleHeadUserId.HasValue && userMap.ContainsKey(r.CircleHeadUserId.Value)
                        ? userMap[r.CircleHeadUserId.Value].Email : null,
            r.RAUserId,
            raName  = r.RAUserId.HasValue && userMap.ContainsKey(r.RAUserId.Value)
                        ? userMap[r.RAUserId.Value].FullName : null,
            raEmail = r.RAUserId.HasValue && userMap.ContainsKey(r.RAUserId.Value)
                        ? userMap[r.RAUserId.Value].Email : null,
            r.IsActive,
            r.CreatedAt,
        }).ToList();

        return Ok(new
        {
            items = result,
            totalCount = total,
            pageNumber,
            pageSize,
            totalPages = (int)Math.Ceiling((double)total / pageSize),
        });
    }

    /// <summary>Get ASM (Role=2) and RA (Role=3) users for dropdowns.</summary>
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers(CancellationToken ct)
    {
        // Include inactive users too so existing assignments always appear in the dropdown
        var asmUsers = await _context.Users
            .AsNoTracking()
            .Where(u => u.Role == UserRole.ASM)
            .OrderBy(u => u.FullName)
            .Select(u => new { u.Id, u.FullName, u.Email, u.IsActive })
            .ToListAsync(ct);

        var raUsers = await _context.Users
            .AsNoTracking()
            .Where(u => u.Role == UserRole.RA)
            .OrderBy(u => u.FullName)
            .Select(u => new { u.Id, u.FullName, u.Email, u.IsActive })
            .ToListAsync(ct);

        return Ok(new { asmUsers, raUsers });
    }

    /// <summary>Create a new state mapping. One per state.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] StateMappingRequest req, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.State))
            return BadRequest(new { message = "State is required." });

        var exists = await _context.StateMappings
            .AnyAsync(s => s.State == req.State.Trim(), ct);
        if (exists)
            return Conflict(new { message = $"A mapping for '{req.State}' already exists." });

        var entity = new StateMapping
        {
            Id               = Guid.NewGuid(),
            State            = req.State.Trim(),
            CircleHeadUserId = req.CircleHeadUserId,
            RAUserId         = req.RAUserId,
            IsActive         = true,
            CreatedAt        = DateTime.UtcNow,
            UpdatedAt        = DateTime.UtcNow,
        };
        _context.StateMappings.Add(entity);
        await _context.SaveChangesAsync(ct);
        _logger.LogInformation("Admin created StateMapping for {State}", entity.State);
        return Ok(new { entity.Id, entity.State, entity.CircleHeadUserId, entity.RAUserId, entity.IsActive, entity.CreatedAt });
    }

    /// <summary>Update CH and RA assignment for a state. State is immutable.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id,
        [FromBody] StateMappingUpdateRequest req, CancellationToken ct)
    {
        var entity = await _context.StateMappings
            .FirstOrDefaultAsync(s => s.Id == id, ct);
        if (entity == null) return NotFound();

        entity.CircleHeadUserId = req.CircleHeadUserId;
        entity.RAUserId         = req.RAUserId;
        entity.IsActive         = req.IsActive;
        entity.UpdatedAt        = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);
        return Ok(new { entity.Id, entity.State, entity.CircleHeadUserId, entity.RAUserId, entity.IsActive, entity.CreatedAt });
    }

    /// <summary>Hard-delete a state mapping.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id, CancellationToken ct)
    {
        var entity = await _context.StateMappings
            .FirstOrDefaultAsync(s => s.Id == id, ct);
        if (entity == null) return NotFound();

        _context.StateMappings.Remove(entity);
        await _context.SaveChangesAsync(ct);
        return NoContent();
    }
}

public record StateMappingRequest(string State, Guid? CircleHeadUserId, Guid? RAUserId);
public record StateMappingUpdateRequest(Guid? CircleHeadUserId, Guid? RAUserId, bool IsActive);
