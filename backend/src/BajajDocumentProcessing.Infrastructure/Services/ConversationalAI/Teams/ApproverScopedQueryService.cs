using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;

/// <summary>
/// Provides all database queries scoped by an approver's role and assigned states.
/// Used by TeamsConversationRouter to fetch data for conversational AI responses.
/// All queries use AsNoTracking() and Select() projection for read-only performance.
/// </summary>
public class ApproverScopedQueryService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly ILogger<ApproverScopedQueryService> _logger;

    public ApproverScopedQueryService(ApplicationDbContext dbContext, ILogger<ApproverScopedQueryService> logger)
    {
        _dbContext = dbContext;
        _logger = logger;
    }

    /// <summary>
    /// Gets pending approvals scoped to the approver's role and states.
    /// ASM/Circle Head: queries PendingCH packages assigned to them or in their states.
    /// RA: queries PendingRA packages in their assigned states.
    /// Ordered by CreatedAt ascending (oldest first), limited to 10 results.
    /// </summary>
    public async Task<List<PendingApprovalSummary>> GetPendingApprovalsAsync(
        Guid userId, string role, string[] states, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "GetPendingApprovalsAsync for user {UserId}, role {Role}, states [{States}]",
            userId, role, string.Join(", ", states));

        var targetState = role == "ASM" ? PackageState.PendingCH : PackageState.PendingRA;

        var query = _dbContext.DocumentPackages
            .AsNoTracking()
            .Where(dp => dp.State == targetState);

        query = ApplyScopeFilter(query, userId, role, states);

        var results = await query
            .OrderBy(dp => dp.CreatedAt)
            .Take(10)
            .Select(dp => new PendingApprovalSummary
            {
                FapId = dp.SubmissionNumber ?? ("FAP-" + dp.Id.ToString().Substring(0, 8).ToUpper()),
                SubmissionId = dp.Id,
                AgencyName = dp.Agency.SupplierName,
                Amount = dp.Invoices
                    .Where(i => !i.IsDeleted && i.TotalAmount.HasValue)
                    .Sum(i => i.TotalAmount!.Value),
                SubmittedAt = dp.CreatedAt,
                DaysPending = (int)(DateTime.UtcNow - dp.CreatedAt).TotalDays,
                State = dp.ActivityState ?? string.Empty
            })
            .ToListAsync(ct);

        _logger.LogInformation(
            "GetPendingApprovalsAsync returned {Count} results for user {UserId}",
            results.Count, userId);

        return results;
    }

    /// <summary>
    /// Gets submission detail by partial FAP ID match within the approver's scope.
    /// Includes ValidationResult and Recommendation navigation properties.
    /// Returns null if the FAP ID is not found or is outside the approver's scope.
    /// </summary>
    public async Task<DocumentPackage?> GetSubmissionDetailAsync(
        Guid userId, string role, string[] states, string fapIdSearch, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "GetSubmissionDetailAsync for user {UserId}, role {Role}, fapIdSearch {FapIdSearch}",
            userId, role, fapIdSearch);

        var cleanSearch = fapIdSearch.Trim();

        var query = _dbContext.DocumentPackages
            .AsNoTracking()
            .Include(dp => dp.Agency)
            .Include(dp => dp.Recommendation)
            .Include(dp => dp.Invoices)
            .Include(dp => dp.Teams)
            .Include(dp => dp.PO)
            .Include(dp => dp.ConfidenceScore)
            .AsQueryable();

        query = ApplyScopeFilter(query, userId, role, states);

        // Try matching by SubmissionNumber first (e.g., FAP-2026-00002, CIQ-TEST-00001)
        var package = await query
            .Where(dp => dp.SubmissionNumber != null &&
                         dp.SubmissionNumber.ToUpper() == cleanSearch.ToUpper())
            .FirstOrDefaultAsync(ct);

        // Fallback: match by partial GUID (legacy FAP-28C9823C format)
        if (package == null)
        {
            var guidSearch = cleanSearch.ToUpperInvariant();
            if (guidSearch.StartsWith("FAP-"))
                guidSearch = guidSearch.Substring(4);

            package = await query
                .Where(dp => dp.Id.ToString().ToUpper().StartsWith(guidSearch))
                .FirstOrDefaultAsync(ct);
        }

        if (package == null)
        {
            _logger.LogInformation(
                "Submission not found for FAP ID search '{FapIdSearch}' within scope of user {UserId}",
                fapIdSearch, userId);
        }

        return package;
    }

    /// <summary>
    /// Gets submissions approved by the specified user within a date range.
    /// Queries RequestApprovalHistory where ApproverId matches and Action is Approved.
    /// Defaults to last 7 days if no date range specified.
    /// </summary>
    public async Task<List<RequestApprovalHistory>> GetApprovedByMeAsync(
        Guid userId, DateTime from, DateTime to, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "GetApprovedByMeAsync for user {UserId}, from {From}, to {To}",
            userId, from, to);

        var results = await _dbContext.RequestApprovalHistories
            .AsNoTracking()
            .Include(h => h.DocumentPackage)
                .ThenInclude(dp => dp.Agency)
            .Include(h => h.DocumentPackage)
                .ThenInclude(dp => dp.Invoices)
            .Include(h => h.DocumentPackage)
                .ThenInclude(dp => dp.PO)
            .Where(h => h.ApproverId == userId)
            .Where(h => h.Action == ApprovalAction.Approved)
            .Where(h => h.ActionDate >= from && h.ActionDate <= to)
            .OrderByDescending(h => h.ActionDate)
            .AsSplitQuery()
            .ToListAsync(ct);

        _logger.LogInformation(
            "GetApprovedByMeAsync returned {Count} results for user {UserId}",
            results.Count, userId);

        return results;
    }

    /// <summary>
    /// Gets submissions rejected by the specified user within a date range.
    /// Queries RequestApprovalHistory where ApproverId matches and Action is Rejected.
    /// Defaults to last 7 days if no date range specified.
    /// </summary>
    public async Task<List<RequestApprovalHistory>> GetRejectedByMeAsync(
        Guid userId, DateTime from, DateTime to, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "GetRejectedByMeAsync for user {UserId}, from {From}, to {To}",
            userId, from, to);

        var results = await _dbContext.RequestApprovalHistories
            .AsNoTracking()
            .Include(h => h.DocumentPackage)
                .ThenInclude(dp => dp.Agency)
            .Include(h => h.DocumentPackage)
                .ThenInclude(dp => dp.Invoices)
            .Include(h => h.DocumentPackage)
                .ThenInclude(dp => dp.PO)
            .Where(h => h.ApproverId == userId)
            .Where(h => h.Action == ApprovalAction.Rejected)
            .Where(h => h.ActionDate >= from && h.ActionDate <= to)
            .OrderByDescending(h => h.ActionDate)
            .AsSplitQuery()
            .ToListAsync(ct);

        _logger.LogInformation(
            "GetRejectedByMeAsync returned {Count} results for user {UserId}",
            results.Count, userId);

        return results;
    }

    /// <summary>
    /// Gets an aggregate activity summary for the approver.
    /// Includes: PendingCount, NewToday, ApprovedThisWeek, ApprovedAmountThisWeek,
    /// RejectedThisWeek, and AvgProcessingDays — all scoped to the approver's states.
    /// </summary>
    public async Task<ApproverActivitySummary> GetActivitySummaryAsync(
        Guid userId, string role, string[] states, CancellationToken ct = default)
    {
        _logger.LogDebug(
            "GetActivitySummaryAsync for user {UserId}, role {Role}",
            userId, role);

        var targetState = role == "ASM" ? PackageState.PendingCH : PackageState.PendingRA;
        var today = DateTime.UtcNow.Date;
        var weekStart = today.AddDays(-(int)today.DayOfWeek);

        // Pending count — packages in the approver's scope with pending status
        var pendingQuery = _dbContext.DocumentPackages
            .AsNoTracking()
            .Where(dp => dp.State == targetState);
        pendingQuery = ApplyScopeFilter(pendingQuery, userId, role, states);

        var pendingCount = await pendingQuery.CountAsync(ct);

        // New today — packages created today in the approver's scope with pending status
        var newToday = await pendingQuery
            .Where(dp => dp.CreatedAt >= today)
            .CountAsync(ct);

        // Approved this week by this user
        var approvedThisWeek = await _dbContext.RequestApprovalHistories
            .AsNoTracking()
            .Where(h => h.ApproverId == userId)
            .Where(h => h.Action == ApprovalAction.Approved)
            .Where(h => h.ActionDate >= weekStart)
            .CountAsync(ct);

        // Approved amount this week — sum of invoice amounts for approved packages
        var approvedPackageIds = await _dbContext.RequestApprovalHistories
            .AsNoTracking()
            .Where(h => h.ApproverId == userId)
            .Where(h => h.Action == ApprovalAction.Approved)
            .Where(h => h.ActionDate >= weekStart)
            .Select(h => h.PackageId)
            .ToListAsync(ct);

        var approvedAmountThisWeek = approvedPackageIds.Count > 0
            ? await _dbContext.Set<Invoice>()
                .AsNoTracking()
                .Where(i => approvedPackageIds.Contains(i.PackageId) && !i.IsDeleted && i.TotalAmount.HasValue)
                .SumAsync(i => i.TotalAmount!.Value, ct)
            : 0m;

        // Rejected this week by this user
        var rejectedThisWeek = await _dbContext.RequestApprovalHistories
            .AsNoTracking()
            .Where(h => h.ApproverId == userId)
            .Where(h => h.Action == ApprovalAction.Rejected)
            .Where(h => h.ActionDate >= weekStart)
            .CountAsync(ct);

        // Average processing days — avg time from package creation to approval/rejection by this user
        // Computed in-memory to avoid EF Core SQL translation issues with DateDiffDay + DefaultIfEmpty + AverageAsync
        var processingDays = await _dbContext.RequestApprovalHistories
            .AsNoTracking()
            .Include(h => h.DocumentPackage)
            .Where(h => h.ApproverId == userId)
            .Where(h => h.Action == ApprovalAction.Approved || h.Action == ApprovalAction.Rejected)
            .Where(h => h.ActionDate >= weekStart)
            .Select(h => new { h.DocumentPackage.CreatedAt, h.ActionDate })
            .ToListAsync(ct);

        var avgProcessingDays = processingDays.Count > 0
            ? processingDays.Average(h => (h.ActionDate - h.CreatedAt).TotalDays)
            : 0.0;

        var summary = new ApproverActivitySummary
        {
            PendingCount = pendingCount,
            NewToday = newToday,
            ApprovedThisWeek = approvedThisWeek,
            ApprovedAmountThisWeek = approvedAmountThisWeek,
            RejectedThisWeek = rejectedThisWeek,
            AvgProcessingDays = Math.Round(avgProcessingDays, 1)
        };

        _logger.LogInformation(
            "GetActivitySummaryAsync for user {UserId}: Pending={Pending}, NewToday={New}, Approved={Approved}, Rejected={Rejected}",
            userId, summary.PendingCount, summary.NewToday, summary.ApprovedThisWeek, summary.RejectedThisWeek);

        return summary;
    }

    /// <summary>
    /// Applies role-based scope filtering to a DocumentPackage query.
    /// ASM: scoped by AssignedCircleHeadUserId or Teams.State in assigned states.
    /// RA: scoped by Teams.State in assigned states.
    /// </summary>
    private static IQueryable<DocumentPackage> ApplyScopeFilter(
        IQueryable<DocumentPackage> query, Guid userId, string role, string[] states)
    {
        if (role == "ASM")
        {
            query = query.Where(dp =>
                dp.AssignedCircleHeadUserId == userId ||
                dp.Teams.Any(t => states.Contains(t.State)));
        }
        else
        {
            query = query.Where(dp =>
                dp.Teams.Any(t => states.Contains(t.State)));
        }

        return query;
    }
}
