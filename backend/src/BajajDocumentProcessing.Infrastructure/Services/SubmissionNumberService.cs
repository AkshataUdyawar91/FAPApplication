using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Persistence;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Generates unique submission numbers in FAP-XXXXXXXX format (FAP- + first 8 chars of a GUID).
/// </summary>
public class SubmissionNumberService : ISubmissionNumberService
{
    private readonly ILogger<SubmissionNumberService> _logger;

    public SubmissionNumberService(
        ApplicationDbContext context,
        ILogger<SubmissionNumberService> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public Task<string> GenerateAsync(CancellationToken cancellationToken = default)
    {
        var submissionNumber = $"FAP-{Guid.NewGuid().ToString("N").Substring(0, 8).ToUpper()}";

        _logger.LogInformation("Generated submission number {SubmissionNumber}", submissionNumber);

        return Task.FromResult(submissionNumber);
    }
}
