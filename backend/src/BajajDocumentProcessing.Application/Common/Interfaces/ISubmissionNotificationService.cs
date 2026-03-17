namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Abstraction for pushing real-time notifications to connected clients.
/// Implemented via SignalR IHubContext in the API/Infrastructure layer.
/// </summary>
public interface ISubmissionNotificationService
{
    /// <summary>
    /// Pushes a ValidationComplete event to all clients subscribed to the given submission.
    /// </summary>
    Task SendValidationCompleteAsync(Guid submissionId, object payload, CancellationToken ct = default);

    /// <summary>
    /// Pushes an ExtractionComplete event to all clients subscribed to the given submission.
    /// </summary>
    Task SendExtractionCompleteAsync(Guid submissionId, object payload, CancellationToken ct = default);

    /// <summary>
    /// Pushes a SubmissionStatusChanged event to all clients subscribed to the given submission.
    /// </summary>
    Task SendSubmissionStatusChangedAsync(Guid submissionId, object payload, CancellationToken ct = default);
}
