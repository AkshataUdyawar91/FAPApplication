namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Tracks the last used submission number per year for CIQ-YYYY-XXXXX format generation.
/// Uses Year as the primary key (no BaseEntity — this is a simple sequence table).
/// Thread-safe increment is handled via MERGE SQL in SubmissionNumberService.
/// </summary>
public class SubmissionSequence
{
    /// <summary>
    /// The calendar year (e.g., 2026). Primary key.
    /// </summary>
    public int Year { get; set; }

    /// <summary>
    /// The last used sequential number for this year. Atomically incremented on each new submission.
    /// </summary>
    public int LastNumber { get; set; }
}
