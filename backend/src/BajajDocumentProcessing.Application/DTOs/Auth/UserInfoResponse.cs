using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Response containing current user information
/// </summary>
public class UserInfoResponse
{
    /// <summary>
    /// User's unique identifier
    /// </summary>
    [JsonPropertyName("userId")]
    public required string UserId { get; init; }
    
    /// <summary>
    /// User's email address
    /// </summary>
    [JsonPropertyName("email")]
    public required string Email { get; init; }
    
    /// <summary>
    /// User's role (Agency, ASM, or HQ)
    /// </summary>
    [JsonPropertyName("role")]
    public required string Role { get; init; }
}
