using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Generates unique submission numbers in FAP-YYYY-NNNNN format (e.g. FAP-2026-00042).
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
        var prefix = $"FAP-{year}-";

        // Count existing submissions for this year to get the next sequence number
        var count = await _context.DocumentPackages
            .Where(p => p.SubmissionNumber != null && p.SubmissionNumber.StartsWith(prefix))
            .CountAsync(cancellationToken);

        var submissionNumber = $"{prefix}{(count + 1):D5}";

        _logger.LogInformation("Generated submission number {SubmissionNumber}", submissionNumber);

        return submissionNumber;
    }
}
