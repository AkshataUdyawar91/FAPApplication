using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for logging audit events
/// </summary>
public class AuditLogService : IAuditLogService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AuditLogService> _logger;

    public AuditLogService(
        IApplicationDbContext context,
        ILogger<AuditLogService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task LogActionAsync(
        Guid userId,
        string action,
        string? entityType = null,
        Guid? entityId = null,
        string? ipAddress = null,
        string? details = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var auditLog = new AuditLog
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Action = action,
                EntityType = entityType,
                EntityId = entityId,
                IpAddress = ipAddress,
                UserAgent = details ?? string.Empty,
                CreatedAt = DateTime.UtcNow
            };

            _context.AuditLogs.Add(auditLog);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Audit log created: User {UserId}, Action {Action}, Entity {EntityType}/{EntityId}, IP {IPAddress}",
                userId, action, entityType, entityId, ipAddress);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating audit log for user {UserId}, action {Action}", userId, action);
            // Don't throw - audit logging should not break the application
        }
    }

    public async Task LogDataAccessAsync(
        Guid userId,
        string dataType,
        Guid dataId,
        string? ipAddress = null,
        CancellationToken cancellationToken = default)
    {
        await LogActionAsync(
            userId,
            "DATA_ACCESS",
            dataType,
            dataId,
            ipAddress,
            $"Accessed {dataType} with ID {dataId}",
            cancellationToken);
    }
}
