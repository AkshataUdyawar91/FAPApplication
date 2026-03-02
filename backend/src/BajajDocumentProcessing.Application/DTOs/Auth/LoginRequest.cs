namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Login request DTO
/// </summary>
public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}
