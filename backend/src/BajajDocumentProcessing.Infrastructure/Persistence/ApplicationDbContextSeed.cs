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
        { "agency2@bajaj.com", UserRole.Agency },
        { "asm@bajaj.com", UserRole.ASM },
        { "asm2@bajaj.com", UserRole.ASM },
        { "asm3@bajaj.com", UserRole.ASM },
        { "asm4@bajaj.com", UserRole.ASM },
        { "asm5@bajaj.com", UserRole.ASM },
        { "asm6@bajaj.com", UserRole.ASM },
        { "asm7@bajaj.com", UserRole.ASM },
        { "asm8@bajaj.com", UserRole.ASM },
        { "asm9@bajaj.com", UserRole.ASM },
        { "asm10@bajaj.com", UserRole.ASM },
        { "ra@bajaj.com", UserRole.RA },
        { "ra2@bajaj.com", UserRole.RA },
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
                CreateUser("agency2@bajaj.com", "Agency User 2", UserRole.Agency, agencyId),
                CreateUser("asm@bajaj.com", "ASM User 1 - Maharashtra", UserRole.ASM, null),
                CreateUser("asm2@bajaj.com", "ASM User 2 - Gujarat", UserRole.ASM, null),
                CreateUser("asm3@bajaj.com", "ASM User 3 - Karnataka", UserRole.ASM, null),
                CreateUser("asm4@bajaj.com", "ASM User 4 - Tamil Nadu", UserRole.ASM, null),
                CreateUser("asm5@bajaj.com", "ASM User 5 - Rajasthan", UserRole.ASM, null),
                CreateUser("asm6@bajaj.com", "ASM User 6 - Uttar Pradesh", UserRole.ASM, null),
                CreateUser("asm7@bajaj.com", "ASM User 7 - Madhya Pradesh", UserRole.ASM, null),
                CreateUser("asm8@bajaj.com", "ASM User 8 - West Bengal", UserRole.ASM, null),
                CreateUser("asm9@bajaj.com", "ASM User 9 - Andhra Pradesh", UserRole.ASM, null),
                CreateUser("asm10@bajaj.com", "ASM User 10 - Kerala", UserRole.ASM, null),
                CreateUser("ra@bajaj.com", "RA User", UserRole.RA, null),
                CreateUser("ra2@bajaj.com", "RA User 2", UserRole.RA, null),
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

        // Seed state GST master data if empty
        if (!await context.StateGstMasters.AnyAsync())
        {
            var states = new[]
            {
                ("JK","Jammu and Kashmir"),("HP","Himachal Pradesh"),("PB","Punjab"),
                ("CH","Chandigarh"),("UT","Uttarakhand"),("HR","Haryana"),
                ("DL","Delhi"),("RJ","Rajasthan"),("UP","Uttar Pradesh"),
                ("BR","Bihar"),("SK","Sikkim"),("AR","Arunachal Pradesh"),
                ("NL","Nagaland"),("MN","Manipur"),("MZ","Mizoram"),
                ("TR","Tripura"),("ML","Meghalaya"),("AS","Assam"),
                ("WB","West Bengal"),("JH","Jharkhand"),("OD","Odisha"),
                ("CT","Chhattisgarh"),("MP","Madhya Pradesh"),("GJ","Gujarat"),
                ("DD","Dadra and Nagar Haveli and Daman and Diu"),("MH","Maharashtra"),
                ("AP","Andhra Pradesh"),("KA","Karnataka"),("GA","Goa"),
                ("KL","Kerala"),("TN","Tamil Nadu"),("TS","Telangana"),
                ("AN","Andaman and Nicobar Islands"),("PY","Puducherry"),
                ("LA","Ladakh"),("LD","Lakshadweep"),
            };

            foreach (var (code, name) in states)
            {
                context.StateGstMasters.Add(new Domain.Entities.StateGstMaster
                {
                    Id = Guid.NewGuid(),
                    StateCode = code,
                    StateName = name,
                    GstPercentage = 18.00m,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });
            }
            await context.SaveChangesAsync();
            Console.WriteLine("[Seed] Added state GST master data");
        }

        // Seed sample POs for the agency (simulates SAP sync)
        if (!await context.POs.AnyAsync())
        {
            var agencyUser2 = await context.Users.FirstOrDefaultAsync(u => u.Email == "agency@bajaj.com");
            var submitterId = agencyUser2?.Id ?? Guid.NewGuid();

            var poData = new[]
            {
                ("PO-2026-001", new DateTime(2026, 1, 15), 500000m, 350000m, "Open", "Maharashtra"),
                ("PO-2026-002", new DateTime(2026, 2, 20), 250000m, 250000m, "Open", "Gujarat"),
                ("PO-2025-045", new DateTime(2025, 11, 10), 750000m, 120000m, "PartiallyConsumed", "Karnataka"),
                ("8110011482", new DateTime(2026, 3, 1), 1200000m, 800000m, "Open", "Tamil Nadu"),
                ("8110011617", new DateTime(2026, 3, 5), 950000m, 950000m, "Open", "Rajasthan"),
                ("8110011618", new DateTime(2026, 3, 5), 680000m, 400000m, "PartiallyConsumed", "Uttar Pradesh"),
                ("8110011700", new DateTime(2026, 2, 28), 320000m, 320000m, "Open", "Maharashtra"),
                ("8110011755", new DateTime(2026, 3, 10), 1500000m, 1100000m, "Open", "Gujarat"),
            };

            foreach (var (poNum, poDate, total, remaining, status, activityState) in poData)
            {
                var pkgId = Guid.NewGuid();
                context.DocumentPackages.Add(new DocumentPackage
                {
                    Id = pkgId,
                    AgencyId = agencyId,
                    SubmittedByUserId = submitterId,
                    State = PackageState.Uploaded,
                    ActivityState = activityState,
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

        // Seed StateMappings for ASM/RA role-based scoping (1 ASM per state)
        if (!await context.StateMappings.AnyAsync())
        {
            var raUser1 = await context.Users.FirstOrDefaultAsync(u => u.Email == "ra@bajaj.com");
            var raUser2 = await context.Users.FirstOrDefaultAsync(u => u.Email == "ra2@bajaj.com");

            // (State, ASM email, RA) — each ASM maps to exactly one state
            var mappings = new (string state, string asmEmail, Guid? raId)[]
            {
                ("Maharashtra",    "asm@bajaj.com",   raUser1?.Id),
                ("Gujarat",        "asm2@bajaj.com",  raUser1?.Id),
                ("Karnataka",      "asm3@bajaj.com",  raUser1?.Id),
                ("Tamil Nadu",     "asm4@bajaj.com",  raUser1?.Id),
                ("Rajasthan",      "asm5@bajaj.com",  raUser1?.Id),
                ("Uttar Pradesh",  "asm6@bajaj.com",  raUser2?.Id),
                ("Madhya Pradesh", "asm7@bajaj.com",  raUser2?.Id),
                ("West Bengal",    "asm8@bajaj.com",  raUser2?.Id),
                ("Andhra Pradesh", "asm9@bajaj.com",  raUser2?.Id),
                ("Kerala",         "asm10@bajaj.com", raUser2?.Id),
            };

            foreach (var (stateName, asmEmail, raId) in mappings)
            {
                var asmUser = await context.Users.FirstOrDefaultAsync(u => u.Email == asmEmail);
                context.StateMappings.Add(new StateMapping
                {
                    Id = Guid.NewGuid(),
                    State = stateName,
                    DealerCode = $"MOCK-{stateName[..3].ToUpper()}",
                    DealerName = $"Mock Dealer - {stateName}",
                    CircleHeadUserId = asmUser?.Id,
                    RAUserId = raId,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });
            }

            await context.SaveChangesAsync();
            Console.WriteLine($"[Seed] Added {mappings.Length} StateMappings (1 ASM per state, 1:1 mapping)");
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
