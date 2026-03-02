using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class AuthorizationGuardrailService : IAuthorizationGuardrailService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AuthorizationGuardrailService> _logger;

    public AuthorizationGuardrailService(
        IApplicationDbContext context,
        ILogger<AuthorizationGuardrailService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task ValidateUserAccessAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user == null)
        {
            _logger.LogWarning("User {UserId} not found", userId);
            throw new Application.Common.Interfaces.UnauthorizedAccessException("User not found");
        }

        // Only HQ users can access ChatService
        if (user.Role != UserRole.HQ)
        {
            _logger.LogWarning("User {UserId} with role {Role} attempted to access analytics chat", userId, user.Role);
            throw new Application.Common.Interfaces.UnauthorizedAccessException("Only HQ users can access analytics chat");
        }

        _logger.LogDebug("User {UserId} authorized for analytics chat", userId);
    }

    public async Task<DataScope> GetUserDataScopeAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user == null)
        {
            _logger.LogWarning("User {UserId} not found", userId);
            throw new Application.Common.Interfaces.UnauthorizedAccessException("User not found");
        }

        // For now, all HQ users have access to all data
        // In a real implementation, this would be based on user permissions/roles
        var dataScope = new DataScope
        {
            States = null, // null means all states
            Campaigns = null, // null means all campaigns
            DateRange = null // null means all dates
        };

        _logger.LogDebug("Retrieved data scope for user {UserId}", userId);
        return dataScope;
    }
}
