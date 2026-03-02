using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Extensions.Configuration;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using BajajDocumentProcessing.Infrastructure.Persistence;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 52: Session Expiration
/// Validates: Requirements 10.7
/// 
/// Property: When a session expires after 30 minutes of inactivity, the system requires re-authentication
/// </summary>
public class SessionExpirationProperties
{
    private ApplicationDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    private IConfiguration CreateTestConfiguration(int expirationMinutes = 30)
    {
        var inMemorySettings = new Dictionary<string, string>
        {
            {"Jwt:Secret", "YourSuperSecretKeyThatIsAtLeast32CharactersLong!"},
            {"Jwt:Issuer", "TestIssuer"},
            {"Jwt:Audience", "TestAudience"},
            {"Jwt:ExpirationMinutes", expirationMinutes.ToString()}
        };

        return new ConfigurationBuilder()
            .AddInMemoryCollection(inMemorySettings!)
            .Build();
    }

    [Theory]
    [InlineData("00000000-0000-0000-0000-000000000001", "test1@test.com")]
    [InlineData("00000000-0000-0000-0000-000000000002", "test2@test.com")]
    [InlineData("00000000-0000-0000-0000-000000000003", "test3@test.com")]
    public void Token_HasExpirationClaim(string userIdStr, string email)
    {
        // Arrange
        var userId = Guid.Parse(userIdStr);
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(userId, email, UserRole.Agency.ToString());

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);

        Assert.True(jwtToken.ValidTo > DateTime.UtcNow, "Token expiration should be in the future");
        Assert.True(jwtToken.ValidTo <= DateTime.UtcNow.AddMinutes(31), "Token should expire within 31 minutes (30 + 1 minute buffer)");
    }

    [Fact]
    public void Token_ExpiresAfter30Minutes()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration(30);
        var authService = new AuthService(context, configuration);
        var beforeGeneration = DateTime.UtcNow;

        // Act
        var token = authService.GenerateToken(Guid.NewGuid(), "test@test.com", UserRole.Agency.ToString());
        var afterGeneration = DateTime.UtcNow;

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);

        var expectedExpiration = beforeGeneration.AddMinutes(30);
        var maxExpectedExpiration = afterGeneration.AddMinutes(30);

        Assert.True(jwtToken.ValidTo >= expectedExpiration, "Token should expire at least 30 minutes from generation");
        Assert.True(jwtToken.ValidTo <= maxExpectedExpiration, "Token should not expire more than 30 minutes from generation");
    }

    [Fact]
    public async Task ExpiredToken_FailsValidation()
    {
        // Arrange - Create token with 0 minute expiration (immediately expired)
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration(0);
        var authService = new AuthService(context, configuration);

        var token = authService.GenerateToken(Guid.NewGuid(), "test@test.com", UserRole.Agency.ToString());

        // Wait a moment to ensure token is expired
        await Task.Delay(1000);

        // Act
        var isValid = await authService.ValidateTokenAsync(token);

        // Assert
        Assert.False(isValid, "Expired token should fail validation");
    }

    [Fact]
    public async Task ValidToken_PassesValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration(30);
        var authService = new AuthService(context, configuration);

        var token = authService.GenerateToken(Guid.NewGuid(), "test@test.com", UserRole.Agency.ToString());

        // Act
        var isValid = await authService.ValidateTokenAsync(token);

        // Assert
        Assert.True(isValid, "Valid token should pass validation");
    }

    [Theory]
    [InlineData(5)]
    [InlineData(15)]
    [InlineData(30)]
    [InlineData(45)]
    [InlineData(60)]
    public void Token_WithCustomExpiration_ExpiresCorrectly(int expirationMinutes)
    {
        // Arrange
        var userId = Guid.NewGuid();
        var email = "test@test.com";
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration(expirationMinutes);
        var authService = new AuthService(context, configuration);
        var beforeGeneration = DateTime.UtcNow;

        // Act
        var token = authService.GenerateToken(userId, email, UserRole.Agency.ToString());
        var afterGeneration = DateTime.UtcNow;

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);

        var expectedExpiration = beforeGeneration.AddMinutes(expirationMinutes);
        var maxExpectedExpiration = afterGeneration.AddMinutes(expirationMinutes);

        Assert.True(jwtToken.ValidTo >= expectedExpiration, $"Token should expire at least {expirationMinutes} minutes from generation");
        Assert.True(jwtToken.ValidTo <= maxExpectedExpiration, $"Token should expire no more than {expirationMinutes} minutes from generation");
    }

    [Fact]
    public async Task RefreshToken_GeneratesNewTokenWithNewExpiration()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration(30);
        var authService = new AuthService(context, configuration);

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = "test@test.com",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password", 12),
            FullName = "Test User",
            Role = UserRole.Agency,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        var originalToken = authService.GenerateToken(user.Id, user.Email, user.Role.ToString());

        // Wait a moment
        await Task.Delay(1000);

        // Act
        var refreshedResponse = await authService.RefreshTokenAsync(originalToken);

        // Assert
        Assert.NotNull(refreshedResponse);
        Assert.NotEqual(originalToken, refreshedResponse.Token);
        Assert.True(refreshedResponse.ExpiresAt > DateTime.UtcNow.AddMinutes(29), "Refreshed token should have new expiration");
    }
}
