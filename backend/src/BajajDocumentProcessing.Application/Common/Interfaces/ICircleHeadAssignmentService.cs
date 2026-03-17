namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for auto-assigning CIRCLE HEAD users to submissions based on state mapping.
/// Uses load balancing when multiple CIRCLE HEADs are available for a state.
/// </summary>
public interface ICircleHeadAssignmentService
{
    /// <summary>
    /// Assigns a CIRCLE HEAD user to a submission based on the submission's activity state.
    /// Returns null if no CIRCLE HEAD is found for the state (manual assignment required).
    /// </summary>
    /// <param name="submissionState">The activity state of the submission (e.g., Maharashtra)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The assigned CIRCLE HEAD user ID, or null if none found</returns>
    Task<Guid?> AssignAsync(string submissionState, CancellationToken cancellationToken = default);
}
