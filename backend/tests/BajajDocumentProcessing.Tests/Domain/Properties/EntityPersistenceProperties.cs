using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BajajDocumentProcessing.Tests.Domain.Properties;

/// <summary>
/// Property 56: Entity Persistence
/// Validates: Requirements 12.1
/// 
/// Property: When any entity is created or modified, the system persists changes to the SQL database immediately
/// </summary>
public class EntityPersistenceProperties
{
    private ApplicationDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    [Theory]
    [InlineData("00000000-0000-0000-0000-000000000001", "test1@test.com", "User One", UserRole.Agency)]
    [InlineData("00000000-0000-0000-0000-000000000002", "test2@test.com", "User Two", UserRole.ASM)]
    [InlineData("00000000-0000-0000-0000-000000000003", "test3@test.com", "User Three", UserRole.HQ)]
    public async Task User_Creation_IsPersisted(string idStr, string email, string fullName, UserRole role)
    {
        // Arrange
        var id = Guid.Parse(idStr);
        await using var context = CreateInMemoryContext();

        var user = new User
        {
            Id = id,
            Email = email,
            PasswordHash = "hash",
            FullName = fullName,
            Role = role,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        // Act
        await context.Users.AddAsync(user);
        var saveResult = await context.SaveChangesAsync();

        // Assert - Verify persistence
        var savedUser = await context.Users.FindAsync(id);

        Assert.True(saveResult > 0, "SaveChanges should return positive count");
        Assert.NotNull(savedUser);
        Assert.Equal(email, savedUser.Email);
        Assert.Equal(fullName, savedUser.FullName);
        Assert.Equal(role, savedUser.Role);
    }

    [Fact]
    public async Task User_Modification_IsPersisted()
    {
        // Arrange
        var id = Guid.NewGuid();
        var originalName = "Original Name";
        var newName = "New Name";
        
        await using var context = CreateInMemoryContext();

        var user = new User
        {
            Id = id,
            Email = $"test{id}@test.com",
            PasswordHash = "hash",
            FullName = originalName,
            Role = UserRole.Agency,
            CreatedAt = DateTime.UtcNow
        };

        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        // Act - Modify user
        user.FullName = newName;
        var saveResult = await context.SaveChangesAsync();

        // Assert
        var modifiedUser = await context.Users.FindAsync(id);

        Assert.True(saveResult > 0, "SaveChanges should return positive count");
        Assert.NotNull(modifiedUser);
        Assert.Equal(newName, modifiedUser.FullName);
        Assert.NotNull(modifiedUser.UpdatedAt);
    }

    [Fact]
    public async Task DocumentPackage_WithAllRelations_IsPersisted()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();
        var documentId = Guid.NewGuid();
        
        await using var context = CreateInMemoryContext();

        var user = new User
        {
            Id = userId,
            Email = $"test{userId}@test.com",
            PasswordHash = "hash",
            FullName = "Test User",
            Role = UserRole.Agency,
            CreatedAt = DateTime.UtcNow
        };

        var package = new DocumentPackage
        {
            Id = packageId,
            SubmittedByUserId = userId,
            State = PackageState.Uploaded,
            CreatedAt = DateTime.UtcNow
        };

        var document = new Document
        {
            Id = documentId,
            PackageId = packageId,
            Type = DocumentType.PO,
            FileName = "test.pdf",
            BlobUrl = "https://blob.com/test.pdf",
            FileSizeBytes = 1000,
            ContentType = "application/pdf",
            CreatedAt = DateTime.UtcNow
        };

        var validationResult = new ValidationResult
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            AllValidationsPassed = true,
            CreatedAt = DateTime.UtcNow
        };

        var confidenceScore = new ConfidenceScore
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            PoConfidence = 85.5,
            InvoiceConfidence = 90.0,
            CostSummaryConfidence = 88.0,
            ActivityConfidence = 75.0,
            PhotosConfidence = 80.0,
            OverallConfidence = 85.0,
            CreatedAt = DateTime.UtcNow
        };

        var recommendation = new Recommendation
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            Type = RecommendationType.Approve,
            Evidence = "All validations passed",
            ConfidenceScore = 85.0,
            CreatedAt = DateTime.UtcNow
        };

        // Act
        await context.Users.AddAsync(user);
        await context.DocumentPackages.AddAsync(package);
        await context.Documents.AddAsync(document);
        await context.ValidationResults.AddAsync(validationResult);
        await context.ConfidenceScores.AddAsync(confidenceScore);
        await context.Recommendations.AddAsync(recommendation);
        var saveResult = await context.SaveChangesAsync();

        // Assert
        var savedPackage = await context.DocumentPackages
            .Include(p => p.Documents)
            .Include(p => p.ValidationResult)
            .Include(p => p.ConfidenceScore)
            .Include(p => p.Recommendation)
            .FirstOrDefaultAsync(p => p.Id == packageId);

        Assert.True(saveResult > 0, "SaveChanges should return positive count");
        Assert.NotNull(savedPackage);
        Assert.Single(savedPackage.Documents);
        Assert.NotNull(savedPackage.ValidationResult);
        Assert.NotNull(savedPackage.ConfidenceScore);
        Assert.NotNull(savedPackage.Recommendation);
    }

    [Fact]
    public async Task Timestamps_AreAutomaticallySet()
    {
        // Arrange
        var id = Guid.NewGuid();
        await using var context = CreateInMemoryContext();
        var beforeCreate = DateTime.UtcNow;

        var user = new User
        {
            Id = id,
            Email = $"test{id}@test.com",
            PasswordHash = "hash",
            FullName = "Test User",
            Role = UserRole.Agency
            // Note: Not setting CreatedAt manually
        };

        // Act
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();
        var afterCreate = DateTime.UtcNow;

        // Modify
        user.FullName = "Modified User";
        await context.SaveChangesAsync();

        // Assert
        var savedUser = await context.Users.FindAsync(id);

        Assert.NotNull(savedUser);
        Assert.True(savedUser.CreatedAt >= beforeCreate && savedUser.CreatedAt <= afterCreate, "CreatedAt should be set automatically on creation");
        Assert.NotNull(savedUser.UpdatedAt);
        Assert.True(savedUser.UpdatedAt >= savedUser.CreatedAt, "UpdatedAt should be after CreatedAt");
    }
}
