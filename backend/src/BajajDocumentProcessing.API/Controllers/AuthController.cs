using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Auth;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Authentication controller for user login, logout, and token management
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
    /// Authenticate user and generate JWT token
    /// </summary>
    /// <param name="request">Login credentials containing email and password</param>
    /// <returns>JWT token and user information on successful authentication</returns>
    /// <response code="200">Returns JWT token and user details</response>
    /// <response code="400">Bad request - missing email or password</response>
    /// <response code="401">Unauthorized - invalid credentials</response>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(MessageResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(MessageResponse), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new MessageResponse { Message = "Email and password are required" });
        }

        var response = await _authService.LoginAsync(request);

        if (response == null)
        {
            _logger.LogWarning("Failed login attempt for email: {Email}", request.Email);
            return Unauthorized(new MessageResponse { Message = "Invalid email or password" });
        }

        _logger.LogInformation("Successful login for user: {Email}", request.Email);
        return Ok(response);
    }

    /// <summary>
    /// Logout current user (client-side token removal in stateless JWT system)
    /// </summary>
    /// <returns>Success message</returns>
    /// <response code="200">Logout successful</response>
    /// <response code="401">Unauthorized - authentication required</response>
    [HttpPost("logout")]
    [Authorize]
    [ProducesResponseType(typeof(MessageResponse), StatusCodes.Status200OK)]
    public IActionResult Logout()
    {
        // In a stateless JWT system, logout is handled client-side by removing the token
        // Server-side logout would require token blacklisting (not implemented in this basic version)
        _logger.LogInformation("User logged out");
        return Ok(new MessageResponse { Message = "Logged out successfully" });
    }

    /// <summary>
    /// Get current authenticated user's information from JWT token
    /// </summary>
    /// <returns>User information including ID, email, and role</returns>
    /// <response code="200">Returns current user information</response>
    /// <response code="401">Unauthorized - authentication required or invalid token</response>
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType(typeof(UserInfoResponse), StatusCodes.Status200OK)]
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

        return Ok(new UserInfoResponse
        {
            UserId = userId,
            Email = email,
            Role = role ?? "Unknown"
        });
    }

    /// <summary>
    /// Refresh an expired or expiring JWT token
    /// </summary>
    /// <param name="request">Refresh token request containing the current token</param>
    /// <returns>New JWT token with extended expiration</returns>
    /// <response code="200">Returns new JWT token</response>
    /// <response code="400">Bad request - token is required</response>
    /// <response code="401">Unauthorized - invalid or expired token</response>
    [HttpPost("refresh")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(MessageResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(MessageResponse), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Token))
        {
            return BadRequest(new MessageResponse { Message = "Token is required" });
        }

        var response = await _authService.RefreshTokenAsync(request.Token);

        if (response == null)
        {
            return Unauthorized(new MessageResponse { Message = "Invalid or expired token" });
        }

        _logger.LogInformation("Token refreshed for user: {Email}", response.Email);
        return Ok(response);
    }
}
