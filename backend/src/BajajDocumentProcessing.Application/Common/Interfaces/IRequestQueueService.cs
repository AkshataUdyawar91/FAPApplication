namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for queuing requests when external services are unavailable
/// </summary>
public interface IRequestQueueService
{
    /// <summary>
    /// Queue a validation request for later processing
    /// </summary>
    Task QueueValidationRequestAsync(Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Process queued validation requests
    /// </summary>
    Task ProcessQueuedRequestsAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Get count of queued requests
    /// </summary>
    Task<int> GetQueuedRequestCountAsync(CancellationToken cancellationToken = default);
}
