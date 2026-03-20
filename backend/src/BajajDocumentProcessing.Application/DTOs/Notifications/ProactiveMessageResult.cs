namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Result of a proactive Teams message send attempt.
/// Captures success/failure, HTTP status, and Teams activity ID for tracking.
/// </summary>
public class ProactiveMessageResult
{
    /// <summary>
    /// Whether the proactive message was sent successfully.
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// HTTP status code returned by the Teams API (e.g., 200, 403, 503).
    /// </summary>
    public int HttpStatusCode { get; set; }

    /// <summary>
    /// Error message if the send failed, null on success.
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Teams activity ID of the sent message, used for tracking and updates.
    /// </summary>
    public string? ActivityId { get; set; }
}
