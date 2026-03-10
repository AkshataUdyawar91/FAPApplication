using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Approval;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Domain.Exceptions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Centralized service for managing the multi-level approval workflow.
/// Encapsulates state transition logic, role validation, comment validation,
/// audit trail recording, and notification dispatch.
/// </summary>
public class ApprovalWorkflowService : IApprovalWorkflowService
{
    private readonly IApplicationDbContext _context;
    private readonly INotificationAgent _notificationAgent;
    private readonly ILogger<ApprovalWorkflowService> _logger;

    /// <summary>
    /// Valid state transitions: (currentState, actionType) → newState.
    /// </summary>
    private static readonly Dictionary<(PackageState, ApprovalActionType), PackageState> ValidTransitions = new()
    {
        { (PackageState.PendingASMApproval, ApprovalActionType.ASMApproved), PackageState.PendingHQApproval },
        { (PackageState.PendingASMApproval, ApprovalActionType.ASMRejected), PackageState.RejectedByASM },
        { (PackageState.PendingHQApproval, ApprovalActionType.RAApproved), PackageState.Approved },
        { (PackageState.PendingHQApproval, ApprovalActionType.RARejected), PackageState.RejectedByRA },
        { (PackageState.RejectedByASM, ApprovalActionType.Resubmitted), PackageState.PendingASMApproval },
        { (PackageState.RejectedByRA, ApprovalActionType.Resubmitted), PackageState.PendingASMApproval },
    };

    /// <summary>
    /// Initializes a new instance of the <see cref="ApprovalWorkflowService"/> class.
    /// </summary>
    public ApprovalWorkflowService(
        IApplicationDbContext context,
        INotificationAgent notificationAgent,
        ILogger<ApprovalWorkflowService> logger)
    {
        _context = context;
        _notificationAgent = notificationAgent;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<ApprovalResultDto> ASMApproveAsync(
        Guid packageId, Guid asmUserId, string comment,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "ASM approval requested for package {PackageId} by user {UserId}",
            packageId, asmUserId);

        var package = await GetPackageOrThrowAsync(packageId, cancellationToken);
        var user = await GetUserOrThrowAsync(asmUserId, cancellationToken);

        ValidateRole(user, UserRole.ASM, "approve");
        ValidateComment(comment);
        var newState = GuardTransition(package.State, ApprovalActionType.ASMApproved);

        var previousState = package.State;
        package.State = newState;

        var action = RecordApprovalAction(
            packageId, asmUserId, ApprovalActionType.ASMApproved,
            previousState, newState, comment);

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Package {PackageId} transitioned from {PreviousState} to {NewState} by ASM {UserId}",
            packageId, previousState, newState, asmUserId);

        // Best-effort notification to RA users
        await NotifyRAUsersAsync(packageId, package, cancellationToken);

        return new ApprovalResultDto
        {
            PackageId = packageId,
            NewState = newState.ToString(),
            Message = "Package approved by ASM. Forwarded to RA for review."
        };
    }

    /// <inheritdoc />
    public async Task<ApprovalResultDto> ASMRejectAsync(
        Guid packageId, Guid asmUserId, string comment,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "ASM rejection requested for package {PackageId} by user {UserId}",
            packageId, asmUserId);

        var package = await GetPackageOrThrowAsync(packageId, cancellationToken);
        var user = await GetUserOrThrowAsync(asmUserId, cancellationToken);

        ValidateRole(user, UserRole.ASM, "reject");
        ValidateComment(comment);
        var newState = GuardTransition(package.State, ApprovalActionType.ASMRejected);

        var previousState = package.State;
        package.State = newState;

        var action = RecordApprovalAction(
            packageId, asmUserId, ApprovalActionType.ASMRejected,
            previousState, newState, comment);

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Package {PackageId} rejected by ASM {UserId}. State: {PreviousState} → {NewState}",
            packageId, asmUserId, previousState, newState);

        // Best-effort notification to Agency user
        await NotifyAgencyUserAsync(
            package.SubmittedByUserId, packageId,
            NotificationType.RejectedByASM, "Package Rejected by ASM",
            $"Your package has been rejected by ASM. Reason: {comment.Trim()}",
            cancellationToken);

        return new ApprovalResultDto
        {
            PackageId = packageId,
            NewState = newState.ToString(),
            Message = "Package rejected by ASM."
        };
    }

    /// <inheritdoc />
    public async Task<ApprovalResultDto> RAApproveAsync(
        Guid packageId, Guid raUserId, string comment,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "RA approval requested for package {PackageId} by user {UserId}",
            packageId, raUserId);

        var package = await GetPackageOrThrowAsync(packageId, cancellationToken);
        var user = await GetUserOrThrowAsync(raUserId, cancellationToken);

        ValidateRole(user, UserRole.HQ, "approve");
        ValidateComment(comment);
        var newState = GuardTransition(package.State, ApprovalActionType.RAApproved);

        var previousState = package.State;
        package.State = newState;

        var action = RecordApprovalAction(
            packageId, raUserId, ApprovalActionType.RAApproved,
            previousState, newState, comment);

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Package {PackageId} approved by RA {UserId}. Final state: {NewState}",
            packageId, raUserId, newState);

        // Best-effort notification to Agency user
        await NotifyAgencyUserAsync(
            package.SubmittedByUserId, packageId,
            NotificationType.Approved, "Package Approved",
            "Your package has been fully approved.",
            cancellationToken);

        return new ApprovalResultDto
        {
            PackageId = packageId,
            NewState = newState.ToString(),
            Message = "Package approved by RA. Final approval granted."
        };
    }

    /// <inheritdoc />
    public async Task<ApprovalResultDto> RARejectAsync(
        Guid packageId, Guid raUserId, string comment,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "RA rejection requested for package {PackageId} by user {UserId}",
            packageId, raUserId);

        var package = await GetPackageOrThrowAsync(packageId, cancellationToken);
        var user = await GetUserOrThrowAsync(raUserId, cancellationToken);

        ValidateRole(user, UserRole.HQ, "reject");
        ValidateComment(comment);
        var newState = GuardTransition(package.State, ApprovalActionType.RARejected);

        var previousState = package.State;
        package.State = newState;

        var action = RecordApprovalAction(
            packageId, raUserId, ApprovalActionType.RARejected,
            previousState, newState, comment);

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Package {PackageId} rejected by RA {UserId}. State: {PreviousState} → {NewState}",
            packageId, raUserId, previousState, newState);

        // Best-effort notification to Agency user
        await NotifyAgencyUserAsync(
            package.SubmittedByUserId, packageId,
            NotificationType.RejectedByRA, "Package Rejected by RA",
            $"Your package has been rejected by RA. Reason: {comment.Trim()}",
            cancellationToken);

        return new ApprovalResultDto
        {
            PackageId = packageId,
            NewState = newState.ToString(),
            Message = "Package rejected by RA."
        };
    }

    /// <inheritdoc />
    public async Task<ApprovalResultDto> ResubmitAsync(
        Guid packageId, Guid agencyUserId, string comment,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Resubmission requested for package {PackageId} by user {UserId}",
            packageId, agencyUserId);

        var package = await GetPackageOrThrowAsync(packageId, cancellationToken);
        var user = await GetUserOrThrowAsync(agencyUserId, cancellationToken);

        // Validate Agency role AND original submitter
        ValidateRole(user, UserRole.Agency, "resubmit");
        if (package.SubmittedByUserId != agencyUserId)
        {
            _logger.LogWarning(
                "User {UserId} attempted to resubmit package {PackageId} owned by {OwnerId}",
                agencyUserId, packageId, package.SubmittedByUserId);
            throw new ForbiddenException(
                "Only the original submitter can resubmit this package.");
        }

        ValidateComment(comment);
        var newState = GuardTransition(package.State, ApprovalActionType.Resubmitted);

        var previousState = package.State;
        package.State = newState;
        package.ResubmissionCount = (package.ResubmissionCount ?? 0) + 1;

        var action = RecordApprovalAction(
            packageId, agencyUserId, ApprovalActionType.Resubmitted,
            previousState, newState, comment);

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Package {PackageId} resubmitted by Agency user {UserId}. ResubmissionCount: {Count}. State: {PreviousState} → {NewState}",
            packageId, agencyUserId, package.ResubmissionCount, previousState, newState);

        // Best-effort notification to ASM users
        await NotifyASMUsersAsync(packageId, package, cancellationToken);

        return new ApprovalResultDto
        {
            PackageId = packageId,
            NewState = newState.ToString(),
            Message = "Package resubmitted for ASM review."
        };
    }

    /// <inheritdoc />
    public async Task<List<ApprovalActionDto>> GetApprovalHistoryAsync(
        Guid packageId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Fetching approval history for package {PackageId}", packageId);

        // Verify package exists
        var packageExists = await _context.DocumentPackages
            .AsNoTracking()
            .AnyAsync(p => p.Id == packageId && !p.IsDeleted, cancellationToken);

        if (!packageExists)
        {
            throw new NotFoundException($"Document package with ID '{packageId}' was not found.");
        }

        var actions = await _context.ApprovalActions
            .AsNoTracking()
            .Include(a => a.ActorUser)
            .Where(a => a.PackageId == packageId && !a.IsDeleted)
            .OrderBy(a => a.ActionTimestamp)
            .Select(a => new ApprovalActionDto
            {
                Id = a.Id,
                PackageId = a.PackageId,
                ActorName = a.ActorUser.FullName,
                ActorRole = a.ActorUser.Role.ToString(),
                ActionType = a.ActionType.ToString(),
                PreviousState = a.PreviousState.ToString(),
                NewState = a.NewState.ToString(),
                Comment = a.Comment,
                ActionTimestamp = a.ActionTimestamp
            })
            .ToListAsync(cancellationToken);

        return actions;
    }

    /// <summary>
    /// Loads a document package by ID or throws NotFoundException.
    /// </summary>
    private async Task<DocumentPackage> GetPackageOrThrowAsync(
        Guid packageId, CancellationToken cancellationToken)
    {
        var package = await _context.DocumentPackages
            .FirstOrDefaultAsync(p => p.Id == packageId && !p.IsDeleted, cancellationToken);

        if (package is null)
        {
            throw new NotFoundException($"Document package with ID '{packageId}' was not found.");
        }

        return package;
    }

    /// <summary>
    /// Loads a user by ID or throws NotFoundException.
    /// </summary>
    private async Task<User> GetUserOrThrowAsync(
        Guid userId, CancellationToken cancellationToken)
    {
        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId && !u.IsDeleted, cancellationToken);

        if (user is null)
        {
            throw new NotFoundException($"User with ID '{userId}' was not found.");
        }

        return user;
    }

    /// <summary>
    /// Validates that the user has the required role for the action.
    /// </summary>
    private void ValidateRole(User user, UserRole requiredRole, string actionName)
    {
        if (user.Role != requiredRole)
        {
            _logger.LogWarning(
                "User {UserId} with role {UserRole} attempted to {Action} but requires role {RequiredRole}",
                user.Id, user.Role, actionName, requiredRole);
            throw new ForbiddenException(
                $"User with role '{user.Role}' is not authorized to {actionName}. Required role: '{requiredRole}'.");
        }
    }

    /// <summary>
    /// Validates that the comment meets minimum length requirements after trimming.
    /// </summary>
    private static void ValidateComment(string comment)
    {
        var trimmed = comment?.Trim() ?? string.Empty;
        if (trimmed.Length < 3)
        {
            throw new ValidationException(
                "Comment", "Comment must be at least 3 characters after trimming whitespace.");
        }
    }

    /// <summary>
    /// Guards the state transition using the valid transitions dictionary.
    /// Returns the new state if valid, throws ConflictException otherwise.
    /// </summary>
    private static PackageState GuardTransition(PackageState currentState, ApprovalActionType actionType)
    {
        if (ValidTransitions.TryGetValue((currentState, actionType), out var newState))
        {
            return newState;
        }

        throw new ConflictException(
            $"Cannot perform '{actionType}' on package in '{currentState}' state.");
    }

    /// <summary>
    /// Records an approval action in the audit trail.
    /// </summary>
    private ApprovalAction RecordApprovalAction(
        Guid packageId, Guid actorUserId, ApprovalActionType actionType,
        PackageState previousState, PackageState newState, string comment)
    {
        var action = new ApprovalAction
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            ActorUserId = actorUserId,
            ActionType = actionType,
            PreviousState = previousState,
            NewState = newState,
            Comment = comment.Trim(),
            ActionTimestamp = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        };

        _context.ApprovalActions.Add(action);
        return action;
    }

    /// <summary>
    /// Best-effort notification to RA (HQ) users about a package pending their review.
    /// </summary>
    private async Task NotifyRAUsersAsync(
        Guid packageId, DocumentPackage package, CancellationToken cancellationToken)
    {
        try
        {
            var raUsers = await _context.Users
                .AsNoTracking()
                .Where(u => u.Role == UserRole.HQ && u.IsActive && !u.IsDeleted)
                .ToListAsync(cancellationToken);

            foreach (var raUser in raUsers)
            {
                await _notificationAgent.SendNotificationAsync(
                    raUser.Id,
                    NotificationType.PendingRAReview,
                    "New Package Awaiting RA Review",
                    $"A package has been approved by ASM and is awaiting your review.",
                    packageId,
                    sendEmail: false,
                    cancellationToken: cancellationToken);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Failed to send RA notification for package {PackageId}. Approval action was not rolled back.",
                packageId);
        }
    }

    /// <summary>
    /// Best-effort notification to ASM users about a resubmitted package.
    /// </summary>
    private async Task NotifyASMUsersAsync(
        Guid packageId, DocumentPackage package, CancellationToken cancellationToken)
    {
        try
        {
            var asmUsers = await _context.Users
                .AsNoTracking()
                .Where(u => u.Role == UserRole.ASM && u.IsActive && !u.IsDeleted)
                .ToListAsync(cancellationToken);

            foreach (var asmUser in asmUsers)
            {
                await _notificationAgent.SendNotificationAsync(
                    asmUser.Id,
                    NotificationType.Resubmitted,
                    "Package Resubmitted for Review",
                    $"A previously rejected package has been resubmitted and is awaiting your review.",
                    packageId,
                    sendEmail: false,
                    cancellationToken: cancellationToken);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Failed to send ASM notification for resubmitted package {PackageId}. Resubmission action was not rolled back.",
                packageId);
        }
    }

    /// <summary>
    /// Best-effort notification to the Agency user who submitted the package.
    /// </summary>
    private async Task NotifyAgencyUserAsync(
        Guid agencyUserId, Guid packageId,
        NotificationType notificationType, string title, string message,
        CancellationToken cancellationToken)
    {
        try
        {
            await _notificationAgent.SendNotificationAsync(
                agencyUserId,
                notificationType,
                title,
                message,
                packageId,
                sendEmail: false,
                cancellationToken: cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Failed to send notification ({NotificationType}) to Agency user {UserId} for package {PackageId}. Approval action was not rolled back.",
                notificationType, agencyUserId, packageId);
        }
    }
}
