using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Auth;

/// <summary>
/// Request DTO for SSO login with Azure AD authorization code
/// </summary>
public class SsoTokenRequest
{
    /// <summary>
    /// Authorization code received from Azure AD after user login
    /// </summary>
    [Required(ErrorMessage = "Authorization code is required")]
    public string Code { get; set; } = string.Empty;

    /// <summary>
    /// Redirect URI used during the authorization request (must match Azure AD app registration)
    /// </summary>
    [Required(ErrorMessage = "Redirect URI is required")]
    public string RedirectUri { get; set; } = string.Empty;
}
