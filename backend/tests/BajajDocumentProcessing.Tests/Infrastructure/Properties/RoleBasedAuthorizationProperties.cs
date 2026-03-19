using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using BajajDocumentProcessing.Infrastructure.Persistence;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 50: Role-Based Authorization
/// Validates: Requirements 10.3, 10.4, 10.5
/// 
/// Property: The system grants access based on user roles (Agency, ASM, HQ)
/// </summary>
public class RoleBasedAuthorizationProperties
{
    private ApplicationDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    private IConfiguration CreateTestConfiguration()
    {
        var inMemorySettings = new Dictionary<string, string>
        {
            {"Jwt:SecretKey", "YourSuperSecretKeyThatIsAtLeast32CharactersLong!"},
            {"Jwt:Issuer", "TestIssuer"},
            {"Jwt:Audience", "TestAudience"},
            {"Jwt:ExpiryMinutes", "30"}
        };

        return new ConfigurationBuilder()
            .AddInMemoryCollection(inMemorySettings!)
            .Build();
    }

    [Theory]
    [InlineData("00000000-0000-0000-0000-000000000001", "agency@test.com", UserRole.Agency)]
    [InlineData("00000000-0000-0000-0000-000000000002", "asm@test.com", UserRole.ASM)]
    [InlineData("00000000-0000-0000-0000-000000000003", "ra@test.com", UserRole.RA)]
    [InlineData("00000000-0000-0000-0000-000000000004", "admin@test.com", UserRole.Admin)]
    public void GeneratedToken_ContainsCorrectRole(string userIdStr, string email, UserRole role)
    {
        // Arrange
        var userId = Guid.Parse(userIdStr);
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(userId, email, role.ToString());

        // Assert - Decode token and verify role claim
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);
        var roleClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role);

        Assert.NotNull(roleClaim);
        Assert.Equal(role.ToString(), roleClaim.Value);
    }

    [Theory]
    [InlineData("00000000-0000-0000-0000-000000000001", "agency@test.com", UserRole.Agency)]
    [InlineData("00000000-0000-0000-0000-000000000002", "asm@test.com", UserRole.ASM)]
    [InlineData("00000000-0000-0000-0000-000000000003", "ra@test.com", UserRole.RA)]
    [InlineData("00000000-0000-0000-0000-000000000004", "admin@test.com", UserRole.Admin)]
    public void Token_ContainsRequiredClaims(string userIdStr, string email, UserRole role)
    {
        // Arrange
        var userId = Guid.Parse(userIdStr);
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(userId, email, role.ToString());

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);

        var userIdClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier);
        var emailClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Email);
        var roleClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role);

        Assert.NotNull(userIdClaim);
        Assert.Equal(userId.ToString(), userIdClaim.Value);
        Assert.NotNull(emailClaim);
        Assert.Equal(email, emailClaim.Value);
        Assert.NotNull(roleClaim);
        Assert.Equal(role.ToString(), roleClaim.Value);
    }

    [Fact]
    public void AgencyRole_ShouldHaveAgencyAccess()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(Guid.NewGuid(), "agency@test.com", UserRole.Agency.ToString());

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);
        var roleClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role);

        Assert.NotNull(roleClaim);
        Assert.Equal("Agency", roleClaim.Value);
    }

    [Fact]
    public void ASMRole_ShouldHaveASMAccess()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(Guid.NewGuid(), "asm@test.com", UserRole.ASM.ToString());

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);
        var roleClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role);

        Assert.NotNull(roleClaim);
        Assert.Equal("ASM", roleClaim.Value);
    }

    [Fact]
    public void RARole_ShouldHaveRAAccess()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(Guid.NewGuid(), "ra@test.com", UserRole.RA.ToString());

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);
        var roleClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role);

        Assert.NotNull(roleClaim);
        Assert.Equal("RA", roleClaim.Value);
    }

    [Fact]
    public void AdminRole_ShouldHaveAdminAccess()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(Guid.NewGuid(), "admin@test.com", UserRole.Admin.ToString());

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);
        var roleClaim = jwtToken.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Role);

        Assert.NotNull(roleClaim);
        Assert.Equal("Admin", roleClaim.Value);
    }

    [Theory]
    [InlineData("00000000-0000-0000-0000-000000000001", "agency@test.com", UserRole.Agency)]
    [InlineData("00000000-0000-0000-0000-000000000002", "asm@test.com", UserRole.ASM)]
    [InlineData("00000000-0000-0000-0000-000000000003", "ra@test.com", UserRole.RA)]
    [InlineData("00000000-0000-0000-0000-000000000004", "admin@test.com", UserRole.Admin)]
    public async Task Token_CanBeValidated(string userIdStr, string email, UserRole role)
    {
        // Arrange
        var userId = Guid.Parse(userIdStr);
        var context = CreateInMemoryContext();
        var configuration = CreateTestConfiguration();
        var authService = new AuthService(context, configuration);

        // Act
        var token = authService.GenerateToken(userId, email, role.ToString());
        var isValid = await authService.ValidateTokenAsync(token);

        // Assert
        Assert.True(isValid, "Generated token should be valid");
    }
}
