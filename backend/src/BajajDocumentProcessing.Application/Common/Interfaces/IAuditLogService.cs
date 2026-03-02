namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for logging audit events
/// </summary>
public interface IAuditLogService
{
    /// <summary>
    /// Log a user action
    /// </summary>
    Task LogActionAsync(
        Guid userId,
        string action,
        string? entityType = null,
        Guid? entityId = null,
        string? ipAddress = null,
        string? details = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Log personal data access
    /// </summary>
    Task LogDataAccessAsync(
        Guid userId,
        string dataType,
        Guid dataId,
        string? ipAddress = null,
        CancellationToken cancellationToken = default);
}
