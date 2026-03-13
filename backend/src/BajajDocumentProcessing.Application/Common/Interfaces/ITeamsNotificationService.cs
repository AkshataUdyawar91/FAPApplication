namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for sending proactive Teams notifications (approval cards, status updates).
/// Abstracts the Bot Framework SDK from the application layer.
/// </summary>
public interface ITeamsNotificationService
{
    /// <summary>
    /// Sends an approval adaptive card to the ASM's Teams conversation
    /// when a FAP reaches PendingASMApproval state.
    /// </summary>
    /// <param name="packageId">The document package ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if the card was sent successfully, false otherwise</returns>
    Task<bool> SendApprovalCardAsync(Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends a status update card to the ASM's Teams conversation
    /// when a FAP state changes (e.g., HQ approved, HQ rejected).
    /// </summary>
    /// <param name="packageId">The document package ID</param>
    /// <param name="newState">The new state description</param>
    /// <param name="details">Additional details about the state change</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if the notification was sent successfully</returns>
    Task<bool> SendStatusUpdateAsync(Guid packageId, string newState, string? details = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Whether the Teams notification service is available (bot installed, conversation captured).
    /// </summary>
    bool IsAvailable { get; }
}
