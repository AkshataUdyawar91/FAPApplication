using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Admin;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>Admin user management service — list, create, update, soft-delete.</summary>
public class UserManagementService : IUserManagementService
{
    private readonly ApplicationDbContext _context;

    public UserManagementService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PagedUsersResponse> GetUsersAsync(
        int pageNumber, int pageSize, string? search, int? roleFilter, CancellationToken ct)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.Users
            .AsNoTracking()
            .Where(u => !u.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(u =>
                u.Email.ToLower().Contains(s) ||
                u.FullName.ToLower().Contains(s));
        }

        if (roleFilter.HasValue)
            query = query.Where(u => (int)u.Role == roleFilter.Value);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(u => ToDto(u))
            .ToListAsync(ct);

        return new PagedUsersResponse
        {
            Items      = items,
            TotalCount = total,
            PageNumber = pageNumber,
            PageSize   = pageSize,
        };
    }

    public async Task<UserDto?> GetUserByIdAsync(Guid id, CancellationToken ct)
    {
        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted, ct);
        return user == null ? null : ToDto(user);
    }

    public async Task<UserDto> CreateUserAsync(CreateUserRequest request, CancellationToken ct)
    {
        var user = new User
        {
            Id           = Guid.NewGuid(),
            Email        = request.Email.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            FullName     = request.FullName.Trim(),
            Role         = (UserRole)request.Role,
            PhoneNumber  = request.PhoneNumber?.Trim(),
            IsActive     = request.IsActive,
            IsDeleted    = false,
            CreatedAt    = DateTime.UtcNow,
            UpdatedAt    = DateTime.UtcNow,
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync(ct);
        return ToDto(user);
    }

    public async Task<UserDto?> UpdateUserAsync(Guid id, UpdateUserRequest request, CancellationToken ct)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted, ct);
        if (user == null) return null;

        user.FullName    = request.FullName.Trim();
        user.Role        = (UserRole)request.Role;
        user.PhoneNumber = request.PhoneNumber?.Trim();
        user.IsActive    = request.IsActive;
        user.UpdatedAt   = DateTime.UtcNow;

        if (!string.IsNullOrWhiteSpace(request.Password))
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

        await _context.SaveChangesAsync(ct);
        return ToDto(user);
    }

    public async Task<bool> DeleteUserAsync(Guid id, CancellationToken ct)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted, ct);
        if (user == null) return false;

        user.IsDeleted = true;
        user.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);
        return true;
    }

    private static UserDto ToDto(User u) => new()
    {
        Id          = u.Id,
        Email       = u.Email,
        FullName    = u.FullName,
        Role        = Enum.GetName(typeof(UserRole), u.Role) ?? u.Role.ToString(),
        RoleValue   = (int)u.Role,
        PhoneNumber = u.PhoneNumber,
        IsActive    = u.IsActive,
        CreatedAt   = u.CreatedAt,
        LastLoginAt = u.LastLoginAt,
    };
}
