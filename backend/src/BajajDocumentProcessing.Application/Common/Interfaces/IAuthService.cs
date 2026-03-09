using BajajDocumentProcessing.Application.DTOs.Auth;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Authentication service interface
/// </summary>
public interface IAuthService
{
    /// <summary>
    /// Authenticates a user with email and password
    /// </summary>
    /// <param name="request">Login request containing email and password</param>
    /// <returns>Login response with JWT token and user details, or null if authentication fails</returns>
    Task<LoginResponse?> LoginAsync(LoginRequest request);

    /// <summary>
    /// Validates a JWT token
    /// </summary>
    /// <param name="token">JWT token to validate</param>
    /// <returns>True if token is valid, false otherwise</returns>
    Task<bool> ValidateTokenAsync(string token);

    /// <summary>
    /// Refreshes an expired JWT token
    /// </summary>
    /// <param name="token">Expired JWT token to refresh</param>
    /// <returns>New login response with refreshed token, or null if refresh fails</returns>
    Task<LoginResponse?> RefreshTokenAsync(string token);

    /// <summary>
    /// Generates a JWT token for a user
    /// </summary>
    /// <param name="userId">User's unique identifier</param>
    /// <param name="email">User's email address</param>
    /// <param name="role">User's role (Agency, ASM, HQ)</param>
    /// <returns>JWT token string</returns>
    string GenerateToken(Guid userId, string email, string role);
}
