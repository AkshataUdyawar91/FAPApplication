using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Login response DTO
/// </summary>
public class LoginResponse
{
    public string Token { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public UserRole Role { get; set; }
    public DateTime ExpiresAt { get; set; }
}
