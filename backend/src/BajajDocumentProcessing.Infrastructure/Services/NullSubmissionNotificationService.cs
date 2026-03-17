using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// No-op implementation of ISubmissionNotificationService.
/// Used as a placeholder until the SignalR hub (Task 11) is implemented.
/// Logs notification attempts but does not push to any clients.
/// </summary>
public class NullSubmissionNotificationService : ISubmissionNotificationService
{
    private readonly ILogger<NullSubmissionNotificationService> _logger;

    public NullSubmissionNotificationService(ILogger<NullSubmissionNotificationService> logger)
    {
        _logger = logger;
    }

    public Task SendValidationCompleteAsync(Guid submissionId, object payload, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "SignalR not configured — skipping ValidationComplete for submission {SubmissionId}",
            submissionId);
        return Task.CompletedTask;
    }

    public Task SendExtractionCompleteAsync(Guid submissionId, object payload, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "SignalR not configured — skipping ExtractionComplete for submission {SubmissionId}",
            submissionId);
        return Task.CompletedTask;
    }

    public Task SendSubmissionStatusChangedAsync(Guid submissionId, object payload, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "SignalR not configured — skipping SubmissionStatusChanged for submission {SubmissionId}",
            submissionId);
        return Task.CompletedTask;
    }
}
