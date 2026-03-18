namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for auto-assigning RA (Regional Approver) users to submissions based on state mapping.
/// Uses load balancing when multiple RA users are available for a state.
/// </summary>
public interface IRAAssignmentService
{
    /// <summary>
    /// Assigns an RA user to a submission based on the submission's activity state.
    /// Returns null if no RA user is found for the state (manual assignment required).
    /// </summary>
    /// <param name="submissionState">The activity state of the submission (e.g., Maharashtra)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The assigned RA user ID, or null if none found</returns>
    Task<Guid?> AssignAsync(string submissionState, CancellationToken cancellationToken = default);
}
