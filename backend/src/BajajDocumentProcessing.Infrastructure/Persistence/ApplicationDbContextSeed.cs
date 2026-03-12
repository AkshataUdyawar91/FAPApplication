using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace BajajDocumentProcessing.Infrastructure.Persistence;

/// <summary>
/// Database seeder for initial test data.
/// Also runs a self-healing role correction on every startup to prevent
/// role mismatches caused by manual SQL inserts or git pull overwrites.
/// </summary>
public static class ApplicationDbContextSeed
{
    /// <summary>
    /// Canonical email-to-role mapping. Single source of truth.
    /// </summary>
    private static readonly Dictionary<string, UserRole> ExpectedRoles = new(StringComparer.OrdinalIgnoreCase)
    {
        { "agency@bajaj.com", UserRole.Agency },
        { "asm@bajaj.com", UserRole.ASM },
        { "ra@bajaj.com", UserRole.RA },
        { "admin@bajaj.com", UserRole.Admin }
    };

    public static async Task SeedAsync(ApplicationDbContext context)
    {
        // Seed default users if none exist
        if (!await context.Users.AnyAsync())
        {
            var users = new List<User>
            {
                CreateUser("agency@bajaj.com", "Agency User", UserRole.Agency),
                CreateUser("asm@bajaj.com", "ASM User", UserRole.ASM),
                CreateUser("ra@bajaj.com", "RA User", UserRole.RA),
                CreateUser("admin@bajaj.com", "Admin User", UserRole.Admin)
            };

            await context.Users.AddRangeAsync(users);
            await context.SaveChangesAsync();
        }

        // Always fix roles on startup — self-healing guard
        await CorrectUserRolesAsync(context);
    }

    /// <summary>
    /// Runs on every startup. Checks known users and corrects their role
    /// if it doesn't match the expected 0-based enum value.
    /// This prevents 403 errors caused by stale DB data after git pull,
    /// manual SQL scripts, or any other source of role drift.
    /// </summary>
    private static async Task CorrectUserRolesAsync(ApplicationDbContext context)
    {
        var knownEmails = ExpectedRoles.Keys.ToList();
        var users = await context.Users
            .Where(u => knownEmails.Contains(u.Email))
            .ToListAsync();

        var corrected = false;
        foreach (var user in users)
        {
            if (ExpectedRoles.TryGetValue(user.Email, out var expectedRole) && user.Role != expectedRole)
            {
                Console.WriteLine($"[SeedFix] Correcting role for {user.Email}: {(int)user.Role} ({user.Role}) → {(int)expectedRole} ({expectedRole})");
                user.Role = expectedRole;
                corrected = true;
            }
        }

        if (corrected)
        {
            await context.SaveChangesAsync();
            Console.WriteLine("[SeedFix] User roles corrected successfully.");
        }
    }

    private static User CreateUser(string email, string fullName, UserRole role)
    {
        return new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
            FullName = fullName,
            Role = role,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
    }
}
