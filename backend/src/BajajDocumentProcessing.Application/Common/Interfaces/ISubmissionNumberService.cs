namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating unique sequential submission numbers in CIQ-YYYY-XXXXX format.
/// Thread-safe via atomic database operations on the SubmissionSequences table.
/// </summary>
public interface ISubmissionNumberService
{
    /// <summary>
    /// Generates the next sequential submission number for the current year.
    /// Uses an atomic MERGE operation to ensure thread safety.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Submission number in CIQ-{year}-{number:D5} format (e.g., CIQ-2026-00042)</returns>
    Task<string> GenerateAsync(CancellationToken cancellationToken = default);
}
