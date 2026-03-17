using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace BajajDocumentProcessing.API.Hubs;

/// <summary>
/// SignalR hub for real-time submission notifications.
/// Clients join submission-specific groups to receive extraction, validation,
/// and status change events.
/// </summary>
[Authorize]
public class SubmissionNotificationHub : Hub
{
    /// <summary>
    /// Client joins a submission-specific group to receive updates.
    /// </summary>
    public async Task JoinSubmission(Guid submissionId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"submission-{submissionId}");
    }

    /// <summary>
    /// Client leaves a submission-specific group.
    /// </summary>
    public async Task LeaveSubmission(Guid submissionId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"submission-{submissionId}");
    }
}
