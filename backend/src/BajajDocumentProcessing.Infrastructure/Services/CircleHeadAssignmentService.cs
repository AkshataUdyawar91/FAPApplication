using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for auto-assigning CIRCLE HEAD users to submissions based on state mapping.
/// Uses load balancing when multiple CIRCLE HEADs are available for a state.
/// </summary>
public class CircleHeadAssignmentService : ICircleHeadAssignmentService
{
    private readonly IApplicationDbContext _db;
    private readonly ILogger<CircleHeadAssignmentService> _logger;

    public CircleHeadAssignmentService(
        IApplicationDbContext db,
        ILogger<CircleHeadAssignmentService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<Guid?> AssignAsync(string submissionState, CancellationToken cancellationToken = default)
    {
        // Query active CIRCLE HEAD users for the given state
        var circleHeadUserIds = await _db.StateMappings
            .Where(sm => sm.State == submissionState && sm.IsActive && !sm.IsDeleted)
            .Select(sm => sm.CircleHeadUserId)
            .Where(id => id != null)
            .Distinct()
            .ToListAsync(cancellationToken);

        if (circleHeadUserIds.Count == 0)
        {
            _logger.LogWarning("No CIRCLE HEAD found for state {State}, flagging for manual assignment", submissionState);
            return null;
        }

        if (circleHeadUserIds.Count == 1)
        {
            _logger.LogInformation("Single CIRCLE HEAD {UserId} assigned for state {State}", circleHeadUserIds[0], submissionState);
            return circleHeadUserIds[0];
        }

        // Load-balance: assign to CIRCLE HEAD with fewest pending submissions
        var leastLoaded = await _db.DocumentPackages
            .Where(dp => circleHeadUserIds.Contains(dp.AssignedCircleHeadUserId)
                          && (dp.State == PackageState.PendingCH || dp.State == PackageState.PendingRA)
                          && !dp.IsDeleted)
            .GroupBy(dp => dp.AssignedCircleHeadUserId)
            .Select(g => new { UserId = g.Key, Count = g.Count() })
            .OrderBy(x => x.Count)
            .FirstOrDefaultAsync(cancellationToken);

        var assignedUserId = leastLoaded?.UserId ?? circleHeadUserIds[0];
        _logger.LogInformation("Load-balanced CIRCLE HEAD {UserId} assigned for state {State} (least loaded)", assignedUserId, submissionState);
        return assignedUserId;
    }
}
