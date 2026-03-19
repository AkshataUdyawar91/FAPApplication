using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Agency;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Infrastructure.Persistence;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>Agency/Supplier master CRUD service.</summary>
public class AgencyService : IAgencyService
{
    private readonly ApplicationDbContext _context;

    public AgencyService(ApplicationDbContext context) => _context = context;

    public async Task<PagedAgenciesResponse> GetAgenciesAsync(
        int pageNumber, int pageSize, string? search, CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.Agencies.AsNoTracking().Where(a => !a.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(a =>
                a.SupplierCode.ToLower().Contains(s) ||
                a.SupplierName.ToLower().Contains(s));
        }

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(a => a.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(a => ToDto(a))
            .ToListAsync(ct);

        return new PagedAgenciesResponse
        {
            Items      = items,
            TotalCount = total,
            PageNumber = pageNumber,
            PageSize   = pageSize,
        };
    }

    public async Task<AgencyDto?> GetAgencyByIdAsync(Guid id, CancellationToken ct = default)
    {
        var a = await _context.Agencies.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
        return a == null ? null : ToDto(a);
    }

    public async Task<AgencyDto?> GetAgencyBySupplierCodeAsync(string code, CancellationToken ct = default)
    {
        var a = await _context.Agencies.AsNoTracking()
            .FirstOrDefaultAsync(x => x.SupplierCode == code && !x.IsDeleted, ct);
        return a == null ? null : ToDto(a);
    }

    public async Task<AgencyDto> CreateAgencyAsync(CreateAgencyRequest request, CancellationToken ct = default)
    {
        var agency = new Agency
        {
            Id           = Guid.NewGuid(),
            SupplierCode = request.SupplierCode.Trim(),
            SupplierName = request.SupplierName.Trim(),
            CreatedAt    = DateTime.UtcNow,
            UpdatedAt    = DateTime.UtcNow,
        };
        _context.Agencies.Add(agency);
        await _context.SaveChangesAsync(ct);
        return ToDto(agency);
    }

    public async Task<AgencyDto?> UpdateAgencyAsync(Guid id, UpdateAgencyRequest request, CancellationToken ct = default)
    {
        var agency = await _context.Agencies
            .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, ct);
        if (agency == null) return null;

        agency.SupplierCode = request.SupplierCode.Trim();
        agency.SupplierName = request.SupplierName.Trim();
        agency.UpdatedAt    = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);
        return ToDto(agency);
    }

    public async Task<bool> DeleteAgencyAsync(Guid id, CancellationToken ct = default)
    {
        var agency = await _context.Agencies
            .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, ct);
        if (agency == null) return false;

        agency.IsDeleted = true;
        agency.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);
        return true;
    }

    private static AgencyDto ToDto(Agency a) => new()
    {
        Id           = a.Id,
        SupplierCode = a.SupplierCode,
        SupplierName = a.SupplierName,
        CreatedAt    = a.CreatedAt,
    };
}
