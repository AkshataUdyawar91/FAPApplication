using BajajDocumentProcessing.Application.DTOs.Admin;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>CRUD operations for admin user management.</summary>
public interface IUserManagementService
{
    Task<PagedUsersResponse> GetUsersAsync(int pageNumber, int pageSize, string? search, int? roleFilter, CancellationToken ct);
    Task<UserDto?> GetUserByIdAsync(Guid id, CancellationToken ct);
    Task<UserDto> CreateUserAsync(CreateUserRequest request, CancellationToken ct);
    Task<UserDto?> UpdateUserAsync(Guid id, UpdateUserRequest request, CancellationToken ct);
    Task<bool> DeleteUserAsync(Guid id, CancellationToken ct);
}
