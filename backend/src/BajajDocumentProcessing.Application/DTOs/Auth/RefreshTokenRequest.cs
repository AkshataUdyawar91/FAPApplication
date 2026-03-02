namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Refresh token request DTO
/// </summary>
public class RefreshTokenRequest
{
    public string Token { get; set; } = string.Empty;
}
