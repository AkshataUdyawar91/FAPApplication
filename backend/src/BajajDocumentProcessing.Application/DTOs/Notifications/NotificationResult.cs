namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Result of a push notification operation
/// </summary>
public class NotificationResult
{
    /// <summary>
    /// Gets or sets whether the operation was successful
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// Gets or sets the error message if the operation failed
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Gets or sets the error code from the platform service
    /// </summary>
    public string? ErrorCode { get; set; }

    /// <summary>
    /// Gets or sets whether the error is due to an invalid device token
    /// </summary>
    public bool IsInvalidToken { get; set; }

    /// <summary>
    /// Gets or sets whether the error is transient and can be retried
    /// </summary>
    public bool IsTransient { get; set; }

    /// <summary>
    /// Creates a successful result
    /// </summary>
    public static NotificationResult Succeeded()
        => new() { Success = true };

    /// <summary>
    /// Creates a failed result with error details
    /// </summary>
    public static NotificationResult Failed(string errorMessage, string? errorCode = null, bool isInvalidToken = false, bool isTransient = false)
        => new()
        {
            Success = false,
            ErrorMessage = errorMessage,
            ErrorCode = errorCode,
            IsInvalidToken = isInvalidToken,
            IsTransient = isTransient
        };
}
