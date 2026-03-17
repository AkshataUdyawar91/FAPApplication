using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.API.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace BajajDocumentProcessing.API.Services;

/// <summary>
/// Real SignalR-backed implementation of ISubmissionNotificationService.
/// Pushes events to clients subscribed to submission-specific groups.
/// </summary>
public class SignalRSubmissionNotificationService : ISubmissionNotificationService
{
    private readonly IHubContext<SubmissionNotificationHub> _hubContext;
    private readonly ILogger<SignalRSubmissionNotificationService> _logger;

    public SignalRSubmissionNotificationService(
        IHubContext<SubmissionNotificationHub> hubContext,
        ILogger<SignalRSubmissionNotificationService> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task SendValidationCompleteAsync(
        Guid submissionId, object payload, CancellationToken ct = default)
    {
        var group = $"submission-{submissionId}";
        _logger.LogInformation(
            "Pushing ValidationComplete to group {Group}", group);
        await _hubContext.Clients.Group(group)
            .SendAsync("ValidationComplete", payload, ct);
    }

    public async Task SendExtractionCompleteAsync(
        Guid submissionId, object payload, CancellationToken ct = default)
    {
        var group = $"submission-{submissionId}";
        _logger.LogInformation(
            "Pushing ExtractionComplete to group {Group}", group);
        await _hubContext.Clients.Group(group)
            .SendAsync("ExtractionComplete", payload, ct);
    }

    public async Task SendSubmissionStatusChangedAsync(
        Guid submissionId, object payload, CancellationToken ct = default)
    {
        var group = $"submission-{submissionId}";
        _logger.LogInformation(
            "Pushing SubmissionStatusChanged to group {Group}", group);
        await _hubContext.Clients.Group(group)
            .SendAsync("SubmissionStatusChanged", payload, ct);
    }
}
