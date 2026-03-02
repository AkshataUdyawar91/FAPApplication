using BajajDocumentProcessing.Application.DTOs.Auth;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Authentication service interface
/// </summary>
public interface IAuthService
{
    Task<LoginResponse?> LoginAsync(LoginRequest request);
    Task<bool> ValidateTokenAsync(string token);
    Task<LoginResponse?> RefreshTokenAsync(string token);
    string GenerateToken(Guid userId, string email, string role);
}
