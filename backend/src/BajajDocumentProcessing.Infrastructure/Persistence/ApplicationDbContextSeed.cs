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
        // Seeding disabled - no mock data
        // Database will be empty on first run
        return;
    }
}
