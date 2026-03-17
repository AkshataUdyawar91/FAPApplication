using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Refresh token request DTO
/// </summary>
public class RefreshTokenRequest
{
    /// <summary>
    /// JWT refresh token
    /// </summary>
    [Required(ErrorMessage = "Token is required")]
    [StringLength(1000, ErrorMessage = "Token cannot exceed 1000 characters")]
    public string Token { get; set; } = string.Empty;
}
