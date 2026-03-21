namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Orchestrates notification delivery for new submissions: channel selection
/// (Teams vs. Email), card building, proactive send, retry, fallback, and logging.
/// Called by WorkflowOrchestrator after PendingASM state transition.
/// </summary>
public interface INotificationDispatcher
{
    /// <summary>
    /// Dispatches a new-submission notification to all ASM users (broadcast model).
    /// For each ASM: selects Teams or Email channel based on TeamsConversation availability,
    /// builds the adaptive card, sends proactively, retries on transient failure,
    /// falls back to email, and logs all attempts.
    /// </summary>
    /// <param name="packageId">The document package ID that reached PendingASM.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task DispatchNewSubmissionNotificationAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
