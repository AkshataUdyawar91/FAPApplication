using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Auth;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Authentication controller
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(IAuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
        _logger = logger;
    }

    /// <summary>
    /// Login endpoint
    /// </summary>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { message = "Email and password are required" });
        }

        var response = await _authService.LoginAsync(request);

        if (response == null)
        {
            _logger.LogWarning("Failed login attempt for email: {Email}", request.Email);
            return Unauthorized(new { message = "Invalid email or password" });
        }

        _logger.LogInformation("Successful login for user: {Email}", request.Email);
        return Ok(response);
    }

    /// <summary>
    /// Logout endpoint
    /// </summary>
    [HttpPost("logout")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public IActionResult Logout()
    {
        // In a stateless JWT system, logout is handled client-side by removing the token
        // Server-side logout would require token blacklisting (not implemented in this basic version)
        _logger.LogInformation("User logged out");
        return Ok(new { message = "Logged out successfully" });
    }

    /// <summary>
    /// Get current user information
    /// </summary>
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public IActionResult GetCurrentUser()
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value;
        var role = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;

        if (string.IsNullOrEmpty(userId) || string.IsNullOrEmpty(email))
        {
            return Unauthorized();
        }

        return Ok(new
        {
            userId,
            email,
            role
        });
    }

    /// <summary>
    /// Refresh token endpoint
    /// </summary>
    [HttpPost("refresh")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Token))
        {
            return BadRequest(new { message = "Token is required" });
        }

        var response = await _authService.RefreshTokenAsync(request.Token);

        if (response == null)
        {
            return Unauthorized(new { message = "Invalid or expired token" });
        }

        _logger.LogInformation("Token refreshed for user: {Email}", response.Email);
        return Ok(response);
    }
}
