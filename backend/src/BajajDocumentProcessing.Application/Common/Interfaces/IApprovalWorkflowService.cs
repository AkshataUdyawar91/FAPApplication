using BajajDocumentProcessing.Application.DTOs.Approval;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Centralized service for managing the multi-level approval workflow.
/// Encapsulates state transition logic, role validation, comment validation,
/// audit trail recording, and notification dispatch.
/// </summary>
public interface IApprovalWorkflowService
{
    /// <summary>
    /// ASM approves a package in PendingASMApproval state.
    /// Transitions to PendingHQApproval, records action, notifies RA users.
    /// </summary>
    /// <param name="packageId">Identifier of the document package.</param>
    /// <param name="asmUserId">Identifier of the ASM reviewer performing the action.</param>
    /// <param name="comment">Mandatory comment explaining the approval.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Result containing the new state and a confirmation message.</returns>
    Task<ApprovalResultDto> ASMApproveAsync(
        Guid packageId,
        Guid asmUserId,
        string comment,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// ASM rejects a package in PendingASMApproval state.
    /// Transitions to RejectedByASM, records action, notifies Agency user.
    /// </summary>
    /// <param name="packageId">Identifier of the document package.</param>
    /// <param name="asmUserId">Identifier of the ASM reviewer performing the action.</param>
    /// <param name="comment">Mandatory comment explaining the rejection reason.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Result containing the new state and a confirmation message.</returns>
    Task<ApprovalResultDto> ASMRejectAsync(
        Guid packageId,
        Guid asmUserId,
        string comment,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// RA approves a package in PendingHQApproval state.
    /// Transitions to Approved, records action, notifies Agency user.
    /// </summary>
    /// <param name="packageId">Identifier of the document package.</param>
    /// <param name="raUserId">Identifier of the RA reviewer performing the action.</param>
    /// <param name="comment">Mandatory comment explaining the approval.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Result containing the new state and a confirmation message.</returns>
    Task<ApprovalResultDto> RAApproveAsync(
        Guid packageId,
        Guid raUserId,
        string comment,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// RA rejects a package in PendingHQApproval state.
    /// Transitions to RejectedByRA, records action, notifies Agency user.
    /// </summary>
    /// <param name="packageId">Identifier of the document package.</param>
    /// <param name="raUserId">Identifier of the RA reviewer performing the action.</param>
    /// <param name="comment">Mandatory comment explaining the rejection reason.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Result containing the new state and a confirmation message.</returns>
    Task<ApprovalResultDto> RARejectAsync(
        Guid packageId,
        Guid raUserId,
        string comment,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Agency resubmits a rejected package.
    /// Transitions to PendingASMApproval, increments resubmission count,
    /// records action, notifies ASM users.
    /// </summary>
    /// <param name="packageId">Identifier of the document package.</param>
    /// <param name="agencyUserId">Identifier of the Agency user performing the resubmission.</param>
    /// <param name="comment">Mandatory comment describing the changes made.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Result containing the new state and a confirmation message.</returns>
    Task<ApprovalResultDto> ResubmitAsync(
        Guid packageId,
        Guid agencyUserId,
        string comment,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Returns the full approval history for a package, ordered by timestamp ascending.
    /// </summary>
    /// <param name="packageId">Identifier of the document package.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Ordered list of approval action records.</returns>
    Task<List<ApprovalActionDto>> GetApprovalHistoryAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
