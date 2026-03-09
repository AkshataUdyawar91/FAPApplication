namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Response for submission status update operations
/// </summary>
public class SubmissionStatusResponse
{
    /// <summary>
    /// Submission package ID
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// Current state of the submission
    /// </summary>
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// Status message describing the operation result
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Number of times the package has been resubmitted by Agency (optional)
    /// </summary>
    public int? ResubmissionCount { get; set; }

    /// <summary>
    /// Number of times the package has been resubmitted to HQ by ASM (optional)
    /// </summary>
    public int? HQResubmissionCount { get; set; }

    /// <summary>
    /// Number of documents in the package (optional)
    /// </summary>
    public int? DocumentCount { get; set; }

    /// <summary>
    /// Processing status for queued operations (optional)
    /// </summary>
    public string? Status { get; set; }

    /// <summary>
    /// Indicates if the operation was successful (optional)
    /// </summary>
    public bool? Success { get; set; }

    /// <summary>
    /// Current state of the package after processing (optional, for process-now endpoint)
    /// </summary>
    public string? CurrentState { get; set; }
}
