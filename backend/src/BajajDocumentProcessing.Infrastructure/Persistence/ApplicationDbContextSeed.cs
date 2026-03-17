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
        // Seed default agency if none exist
        Guid agencyId;
        var existingAgency = await context.Agencies.FirstOrDefaultAsync();
        if (existingAgency != null)
        {
            agencyId = existingAgency.Id;
        }
        else
        {
            agencyId = Guid.NewGuid();
            context.Agencies.Add(new Agency
            {
                Id = agencyId,
                SupplierCode = "V001",
                SupplierName = "Demo Agency",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
            await context.SaveChangesAsync();
        }

        // Seed default users if none exist
        if (!await context.Users.AnyAsync())
        {
            var users = new List<User>
            {
                CreateUser("agency@bajaj.com", "Agency User", UserRole.Agency, agencyId),
                CreateUser("asm@bajaj.com", "ASM User", UserRole.ASM, null),
                CreateUser("ra@bajaj.com", "RA User", UserRole.RA, null),
                CreateUser("admin@bajaj.com", "Admin User", UserRole.Admin, null)
            };

            await context.Users.AddRangeAsync(users);
            await context.SaveChangesAsync();
        }

        // Ensure agency user has AgencyId set (fix for existing databases)
        var agencyUser = await context.Users
            .FirstOrDefaultAsync(u => u.Email == "agency@bajaj.com");
        if (agencyUser != null && agencyUser.AgencyId == null)
        {
            agencyUser.AgencyId = agencyId;
            await context.SaveChangesAsync();
            Console.WriteLine($"[SeedFix] Linked agency user to agency {agencyId}");
        }

        // Always fix roles on startup — self-healing guard
        await CorrectUserRolesAsync(context);

        // Seed sample POs for the agency (simulates SAP sync)
        if (!await context.POs.AnyAsync())
        {
            var agencyUser2 = await context.Users.FirstOrDefaultAsync(u => u.Email == "agency@bajaj.com");
            var submitterId = agencyUser2?.Id ?? Guid.NewGuid();

            var poData = new[]
            {
                ("PO-2026-001", new DateTime(2026, 1, 15), 500000m, 350000m, "Open"),
                ("PO-2026-002", new DateTime(2026, 2, 20), 250000m, 250000m, "Open"),
                ("PO-2025-045", new DateTime(2025, 11, 10), 750000m, 120000m, "PartiallyConsumed"),
                ("8110011482", new DateTime(2026, 3, 1), 1200000m, 800000m, "Open"),
                ("8110011617", new DateTime(2026, 3, 5), 950000m, 950000m, "Open"),
                ("8110011618", new DateTime(2026, 3, 5), 680000m, 400000m, "PartiallyConsumed"),
                ("8110011700", new DateTime(2026, 2, 28), 320000m, 320000m, "Open"),
                ("8110011755", new DateTime(2026, 3, 10), 1500000m, 1100000m, "Open"),
            };

            foreach (var (poNum, poDate, total, remaining, status) in poData)
            {
                var pkgId = Guid.NewGuid();
                context.DocumentPackages.Add(new DocumentPackage
                {
                    Id = pkgId,
                    AgencyId = agencyId,
                    SubmittedByUserId = submitterId,
                    State = PackageState.Uploaded,
                    CurrentStep = 0,
                    VersionNumber = 1,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });

                context.POs.Add(new PO
                {
                    Id = Guid.NewGuid(),
                    PackageId = pkgId,
                    AgencyId = agencyId,
                    PONumber = poNum,
                    PODate = poDate,
                    VendorName = "Demo Agency",
                    TotalAmount = total,
                    RemainingBalance = remaining,
                    POStatus = status,
                    FileName = "seed.pdf",
                    BlobUrl = $"seed://{poNum}",
                    ContentType = "application/pdf",
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });
            }

            await context.SaveChangesAsync();
            Console.WriteLine("[Seed] Added 8 sample POs for Demo Agency");
        }
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

    private static User CreateUser(string email, string fullName, UserRole role, Guid? agencyId)
    {
        return new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
            FullName = fullName,
            Role = role,
            AgencyId = agencyId,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
    }
}
