namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Paginated response containing notification history items
/// </summary>
public record NotificationHistoryResponse(
    IEnumerable<NotificationHistoryItem> Items,
    int TotalCount,
    int PageNumber,
    int PageSize
);

/// <summary>
/// Individual notification history entry for audit and tracking
/// </summary>
public record NotificationHistoryItem(
    Guid Id,
    Guid UserId,
    string NotificationType,
    string Channel,
    string Platform,
    string Status,
    string? ErrorMessage,
    DateTime SentAt,
    string CorrelationId
);
