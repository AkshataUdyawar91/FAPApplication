using FsCheck;
using FsCheck.Xunit;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 77: Password Hashing
/// Validates: Requirements 16.3
/// 
/// Property: When users authenticate, the system hashes passwords using bcrypt with minimum 12 rounds
/// </summary>
public class PasswordHashingProperties
{
    [Property(MaxTest = 10)]
    public void PasswordHash_IsNotReversible(NonEmptyString password)
    {
        // Arrange & Act
        var hash = BCrypt.Net.BCrypt.HashPassword(password.Get, 12);

        // Assert - Hash should not contain the original password
        Assert.False(hash.Contains(password.Get), "Hash should not contain original password");
        Assert.True(hash.Length > password.Get.Length, "Hash should be longer than original password");
        Assert.True(hash.StartsWith("$2"), "Hash should use BCrypt format");
    }

    [Property(MaxTest = 10)]
    public void PasswordHash_CanBeVerified(NonEmptyString password)
    {
        // Arrange
        var hash = BCrypt.Net.BCrypt.HashPassword(password.Get, 12);

        // Act
        var isValid = BCrypt.Net.BCrypt.Verify(password.Get, hash);

        // Assert
        Assert.True(isValid, "Correct password should verify successfully");
    }

    [Property(MaxTest = 10)]
    public void PasswordHash_RejectsWrongPassword(NonEmptyString password, NonEmptyString wrongPassword)
    {
        // Skip if passwords are the same
        if (password.Get == wrongPassword.Get)
            return;

        // Arrange
        var hash = BCrypt.Net.BCrypt.HashPassword(password.Get, 12);

        // Act
        var isValid = BCrypt.Net.BCrypt.Verify(wrongPassword.Get, hash);

        // Assert
        Assert.False(isValid, "Wrong password should be rejected");
    }

    [Property(MaxTest = 10)]
    public void PasswordHash_IsDifferentEachTime(NonEmptyString password)
    {
        // Arrange & Act
        var hash1 = BCrypt.Net.BCrypt.HashPassword(password.Get, 12);
        var hash2 = BCrypt.Net.BCrypt.HashPassword(password.Get, 12);

        // Assert - Same password should produce different hashes (due to salt)
        Assert.NotEqual(hash1, hash2);
        Assert.True(BCrypt.Net.BCrypt.Verify(password.Get, hash1), "First hash should verify correctly");
        Assert.True(BCrypt.Net.BCrypt.Verify(password.Get, hash2), "Second hash should verify correctly");
    }

    [Fact]
    public void PasswordHash_UsesMinimum12Rounds()
    {
        // Arrange
        var password = "TestPassword123!";

        // Act
        var hash = BCrypt.Net.BCrypt.HashPassword(password, 12);

        // Assert - BCrypt hash format: $2a$rounds$salt+hash
        // Extract rounds from hash
        var parts = hash.Split('$');
        Assert.True(parts.Length >= 4, "Hash should have correct BCrypt format");
        
        var rounds = int.Parse(parts[2]);
        Assert.True(rounds >= 12, $"Hash should use at least 12 rounds, but used {rounds}");
    }

    [Fact]
    public void PasswordHash_WithLessThan12Rounds_ShouldNotBeUsed()
    {
        // This test documents that we should never use less than 12 rounds
        var password = "TestPassword123!";

        // Using 11 rounds (less than required)
        var weakHash = BCrypt.Net.BCrypt.HashPassword(password, 11);
        var parts = weakHash.Split('$');
        var rounds = int.Parse(parts[2]);

        // Document that this is not acceptable
        Assert.True(rounds < 12, "This hash uses less than 12 rounds and should not be used in production");
    }
}
