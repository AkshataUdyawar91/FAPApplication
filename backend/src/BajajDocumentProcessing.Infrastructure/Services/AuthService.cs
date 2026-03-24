using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Auth;
using BajajDocumentProcessing.Infrastructure.Persistence;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Authentication service implementation
/// </summary>
public class AuthService : IAuthService
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<AuthService> _logger;
    private readonly string _jwtSecret;
    private readonly string _jwtIssuer;
    private readonly string _jwtAudience;
    private readonly int _jwtExpirationMinutes;

    public AuthService(
        ApplicationDbContext context,
        IConfiguration configuration,
        IHttpClientFactory httpClientFactory,
        ILogger<AuthService> logger)
    {
        _context = context;
        _configuration = configuration;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _jwtSecret = configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("JWT Secret not configured");
        _jwtIssuer = configuration["Jwt:Issuer"] ?? "BajajDocumentProcessing";
        _jwtAudience = configuration["Jwt:Audience"] ?? "BajajDocumentProcessing";
        _jwtExpirationMinutes = int.Parse(configuration["Jwt:ExpiryMinutes"] ?? "30");
    }

    public async Task<LoginResponse?> LoginAsync(LoginRequest request)
    {
        // Find user by email
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Email == request.Email && u.IsActive);

        if (user == null)
        {
            Console.WriteLine($"[AuthService] User not found or inactive: {request.Email}");
            return null; // User not found or inactive
        }

        Console.WriteLine($"[AuthService] User found: {user.Email}");
        Console.WriteLine($"[AuthService] Stored hash: {user.PasswordHash}");
        Console.WriteLine($"[AuthService] Attempting to verify password...");

        // Verify password using BCrypt
        try
        {
            var isValid = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
            Console.WriteLine($"[AuthService] Password verification result: {isValid}");
            
            if (!isValid)
            {
                return null; // Invalid password
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[AuthService] BCrypt verification error: {ex.Message}");
            return null;
        }

        // Update last login timestamp
        user.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        // Generate JWT token with role name (not numeric value)
        var roleName = Enum.GetName(typeof(Domain.Enums.UserRole), user.Role) ?? user.Role.ToString();
        var token = GenerateToken(user.Id, user.Email, roleName);
        var expiresAt = DateTime.UtcNow.AddMinutes(_jwtExpirationMinutes);

        return new LoginResponse
        {
            Token = token,
            UserId = user.Id,
            Email = user.Email,
            FullName = user.FullName,
            Role = roleName,
            ExpiresAt = expiresAt
        };
    }

    public async Task<bool> ValidateTokenAsync(string token)
    {
        try
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(_jwtSecret);

            tokenHandler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ValidateIssuer = true,
                ValidIssuer = _jwtIssuer,
                ValidateAudience = true,
                ValidAudience = _jwtAudience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            }, out SecurityToken validatedToken);

            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<LoginResponse?> RefreshTokenAsync(string token)
    {
        try
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(_jwtSecret);

            // Validate the token (even if expired, we want to extract claims)
            var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ValidateIssuer = true,
                ValidIssuer = _jwtIssuer,
                ValidateAudience = true,
                ValidAudience = _jwtAudience,
                ValidateLifetime = false, // Don't validate lifetime for refresh
                ClockSkew = TimeSpan.Zero
            }, out SecurityToken validatedToken);

            var jwtToken = (JwtSecurityToken)validatedToken;
            var userId = Guid.Parse(principal.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? string.Empty);

            // Get user from database
            var user = await _context.Users.FindAsync(userId);
            if (user == null || !user.IsActive)
            {
                return null;
            }

            // Generate new token with role name (not numeric value)
            var roleName = Enum.GetName(typeof(Domain.Enums.UserRole), user.Role) ?? user.Role.ToString();
            var newToken = GenerateToken(user.Id, user.Email, roleName);
            var expiresAt = DateTime.UtcNow.AddMinutes(_jwtExpirationMinutes);

            return new LoginResponse
            {
                Token = newToken,
                UserId = user.Id,
                Email = user.Email,
                FullName = user.FullName,
                Role = roleName,
                ExpiresAt = expiresAt
            };
        }
        catch
        {
            return null;
        }
    }

    public string GenerateToken(Guid userId, string email, string role)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.ASCII.GetBytes(_jwtSecret);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Email, email),
            new Claim(ClaimTypes.Role, role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(_jwtExpirationMinutes),
            Issuer = _jwtIssuer,
            Audience = _jwtAudience,
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }

    /// <summary>
    /// Exchanges an Azure AD authorization code for tokens, extracts the user email,
    /// looks up the user in the local database, and returns a local JWT.
    /// </summary>
    public async Task<LoginResponse?> SsoLoginAsync(string authorizationCode, string redirectUri)
    {
        var tenantId = _configuration["AzureAd:TenantId"];
        var clientId = _configuration["AzureAd:ClientId"];
        var clientSecret = _configuration["AzureAd:ClientSecret"];

        if (string.IsNullOrEmpty(tenantId) || string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
        {
            _logger.LogError("Azure AD configuration is missing (TenantId, ClientId, or ClientSecret)");
            return null;
        }

        // Exchange authorization code for tokens at Azure AD token endpoint
        var tokenEndpoint = $"https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token";
        var httpClient = _httpClientFactory.CreateClient();

        var tokenRequestBody = new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code",
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["code"] = authorizationCode,
            ["redirect_uri"] = redirectUri,
            ["scope"] = "openid profile email"
        };

        HttpResponseMessage tokenResponse;
        try
        {
            tokenResponse = await httpClient.PostAsync(tokenEndpoint, new FormUrlEncodedContent(tokenRequestBody));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to contact Azure AD token endpoint");
            return null;
        }

        var responseContent = await tokenResponse.Content.ReadAsStringAsync();

        if (!tokenResponse.IsSuccessStatusCode)
        {
            _logger.LogWarning("Azure AD token exchange failed: {StatusCode} {Response}",
                tokenResponse.StatusCode, responseContent);
            return null;
        }

        // Parse the token response to get id_token
        using var jsonDoc = JsonDocument.Parse(responseContent);
        var root = jsonDoc.RootElement;

        if (!root.TryGetProperty("id_token", out var idTokenElement))
        {
            _logger.LogWarning("Azure AD response missing id_token");
            return null;
        }

        // Decode the id_token (JWT) to extract claims — we trust Azure AD issued it
        var handler = new JwtSecurityTokenHandler();
        var idToken = handler.ReadJwtToken(idTokenElement.GetString());

        var email = idToken.Claims.FirstOrDefault(c => c.Type == "preferred_username")?.Value
                 ?? idToken.Claims.FirstOrDefault(c => c.Type == "email")?.Value
                 ?? idToken.Claims.FirstOrDefault(c => c.Type == "upn")?.Value;

        var aadObjectId = idToken.Claims.FirstOrDefault(c => c.Type == "oid")?.Value;
        var displayName = idToken.Claims.FirstOrDefault(c => c.Type == "name")?.Value;

        if (string.IsNullOrEmpty(email))
        {
            _logger.LogWarning("Azure AD id_token missing email/preferred_username claim");
            return null;
        }

        _logger.LogInformation("SSO login attempt for email: {Email}, AadObjectId: {Oid}", email, aadObjectId);

        // Look up user by AadObjectId first, then by email
        var user = !string.IsNullOrEmpty(aadObjectId)
            ? await _context.Users.FirstOrDefaultAsync(u => u.AadObjectId == aadObjectId && u.IsActive)
            : null;

        user ??= await _context.Users.FirstOrDefaultAsync(u => u.Email == email && u.IsActive);

        if (user == null)
        {
            _logger.LogWarning("SSO login failed: no local user found for email {Email}", email);
            return null;
        }

        // Link AadObjectId if not already set
        if (!string.IsNullOrEmpty(aadObjectId) && string.IsNullOrEmpty(user.AadObjectId))
        {
            user.AadObjectId = aadObjectId;
            _logger.LogInformation("Linked AadObjectId {Oid} to user {Email}", aadObjectId, email);
        }

        // Update last login
        user.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        // Generate local JWT
        var roleName = Enum.GetName(typeof(Domain.Enums.UserRole), user.Role) ?? user.Role.ToString();
        var localToken = GenerateToken(user.Id, user.Email, roleName);
        var expiresAt = DateTime.UtcNow.AddMinutes(_jwtExpirationMinutes);

        _logger.LogInformation("SSO login successful for user: {Email}, Role: {Role}", user.Email, roleName);

        return new LoginResponse
        {
            Token = localToken,
            UserId = user.Id,
            Email = user.Email,
            FullName = user.FullName,
            Role = roleName,
            ExpiresAt = expiresAt
        };
    }
}
