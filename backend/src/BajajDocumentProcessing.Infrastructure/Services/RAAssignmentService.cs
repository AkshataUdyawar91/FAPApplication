using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for auto-assigning RA (Regional Approver) users to submissions based on state mapping.
/// Uses load balancing when multiple RA users are available for a state.
/// </summary>
public class RAAssignmentService : IRAAssignmentService
{
    private readonly IApplicationDbContext _db;
    private readonly ILogger<RAAssignmentService> _logger;

    public RAAssignmentService(
        IApplicationDbContext db,
        ILogger<RAAssignmentService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<Guid?> AssignAsync(string submissionState, CancellationToken cancellationToken = default)
    {
        // Query active RA users for the given state (read-only, no tracking)
        var raUserIds = await _db.StateMappings
            .AsNoTracking()
            .Where(sm => sm.State == submissionState && sm.IsActive && !sm.IsDeleted && sm.RAUserId != null)
            .Select(sm => sm.RAUserId)
            .Distinct()
            .ToListAsync(cancellationToken);

        if (raUserIds.Count == 0)
        {
            _logger.LogWarning("No RA user found for state {State}, flagging for manual assignment", submissionState);
            return null;
        }

        if (raUserIds.Count == 1)
        {
            _logger.LogInformation("Single RA user {UserId} assigned for state {State}", raUserIds[0], submissionState);
            return raUserIds[0];
        }

        // Load-balance: assign to RA user with fewest PendingRA submissions
        var leastLoaded = await _db.DocumentPackages
            .AsNoTracking()
            .Where(dp => raUserIds.Contains(dp.AssignedRAUserId)
                          && dp.State == PackageState.PendingRA
                          && !dp.IsDeleted)
            .GroupBy(dp => dp.AssignedRAUserId)
            .Select(g => new { UserId = g.Key, Count = g.Count() })
            .OrderBy(x => x.Count)
            .FirstOrDefaultAsync(cancellationToken);

        var assignedUserId = leastLoaded?.UserId ?? raUserIds[0];
        _logger.LogInformation("Load-balanced RA user {UserId} assigned for state {State} (least loaded)", assignedUserId, submissionState);
        return assignedUserId;
    }
}
