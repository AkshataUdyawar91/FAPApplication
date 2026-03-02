using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace BajajDocumentProcessing.Infrastructure.Persistence;

/// <summary>
/// Database seeder for initial test data
/// </summary>
public static class ApplicationDbContextSeed
{
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        // Check if data already exists
        if (await context.Users.AnyAsync())
        {
            return; // Database has been seeded
        }

        // Seed users with different roles
        var users = new List<User>
        {
            new User
            {
                Id = Guid.NewGuid(),
                Email = "agency@bajaj.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!", 12),
                FullName = "Agency User",
                Role = UserRole.Agency,
                PhoneNumber = "+91-9876543210",
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            },
            new User
            {
                Id = Guid.NewGuid(),
                Email = "asm@bajaj.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!", 12),
                FullName = "ASM User",
                Role = UserRole.ASM,
                PhoneNumber = "+91-9876543211",
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            },
            new User
            {
                Id = Guid.NewGuid(),
                Email = "hq@bajaj.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!", 12),
                FullName = "HQ User",
                Role = UserRole.HQ,
                PhoneNumber = "+91-9876543212",
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            }
        };

        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();
    }
}
