using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace BajajDocumentProcessing.Infrastructure.Persistence;

/// <summary>
/// Database seeder for initial test data
/// </summary>
public static class ApplicationDbContextSeed
{
    // CHANGE: Re-enabled seeding to create default users for new databases
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        // Only seed if no users exist (idempotent)
        if (await context.Users.AnyAsync())
        {
            return;
        }

        var users = new List<User>
        {
            new User
            {
                Id = Guid.NewGuid(),
                Email = "agency@bajaj.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
                FullName = "Agency User",
                Role = UserRole.Agency,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            },
            new User
            {
                Id = Guid.NewGuid(),
                Email = "asm@bajaj.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
                FullName = "ASM User",
                Role = UserRole.ASM,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            },
            new User
            {
                Id = Guid.NewGuid(),
                Email = "hq@bajaj.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
                FullName = "HQ User",
                Role = UserRole.HQ,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            }
        };

        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();
    }
}
