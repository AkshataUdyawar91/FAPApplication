using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Response returned after successful user authentication
/// </summary>
public class LoginResponse
{
    /// <summary>
    /// JWT authentication token for subsequent API requests
    /// </summary>
    [JsonPropertyName("token")]
    public required string Token { get; init; }
    
    /// <summary>
    /// User's unique identifier
    /// </summary>
    [JsonPropertyName("userId")]
    public required Guid UserId { get; init; }
    
    /// <summary>
    /// User's email address
    /// </summary>
    [JsonPropertyName("email")]
    public required string Email { get; init; }
    
    /// <summary>
    /// User's full name
    /// </summary>
    [JsonPropertyName("fullName")]
    public required string FullName { get; init; }

    /// <summary>
    /// User's role (Agency, ASM, or HQ)
    /// </summary>
    [JsonPropertyName("role")]
    public required string Role { get; init; }
    
    /// <summary>
    /// UTC timestamp when the token expires
    /// </summary>
    [JsonPropertyName("expiresAt")]
    public required DateTime ExpiresAt { get; init; }
}
