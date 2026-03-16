using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
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
    private readonly string _jwtSecret;
    private readonly string _jwtIssuer;
    private readonly string _jwtAudience;
    private readonly int _jwtExpirationMinutes;

    public AuthService(ApplicationDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
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
}
