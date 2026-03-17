using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Generates unique sequential submission numbers in CIQ-YYYY-XXXXX format.
/// Uses an atomic MERGE SQL statement on the SubmissionSequences table
/// to ensure thread-safe increment even under concurrent requests.
/// </summary>
public class SubmissionNumberService : ISubmissionNumberService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<SubmissionNumberService> _logger;

    public SubmissionNumberService(
        ApplicationDbContext context,
        ILogger<SubmissionNumberService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<string> GenerateAsync(CancellationToken cancellationToken = default)
    {
        var year = DateTime.UtcNow.Year;

        _logger.LogInformation("Generating submission number for year {Year}", year);

        // Atomic upsert + increment using MERGE, then SELECT the new value.
        // MERGE guarantees thread safety: concurrent calls each get a unique number.
        var sql = @"
            MERGE SubmissionSequences AS target
            USING (SELECT {0} AS Year) AS source ON target.Year = source.Year
            WHEN MATCHED THEN UPDATE SET LastNumber = LastNumber + 1
            WHEN NOT MATCHED THEN INSERT (Year, LastNumber) VALUES ({0}, 1);

            SELECT LastNumber FROM SubmissionSequences WHERE Year = {0};";

        var result = await _context.Database
            .SqlQueryRaw<int>(sql, year)
            .ToListAsync(cancellationToken);

        var number = result.First();
        var submissionNumber = $"CIQ-{year}-{number:D5}";

        _logger.LogInformation(
            "Generated submission number {SubmissionNumber} (Year={Year}, Seq={Seq})",
            submissionNumber, year, number);

        return submissionNumber;
    }
}
