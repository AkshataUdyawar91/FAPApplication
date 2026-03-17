using BajajDocumentProcessing.Application.DTOs.Approval;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing the approval workflow on document packages.
/// Handles approval/rejection actions, approval history, and comments.
/// </summary>
public interface IApprovalService
{
    /// <summary>
    /// Records an approval action (approve/reject) on a document package.
    /// Validates the caller's role against the current package state.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="approverId">The user performing the action.</param>
    /// <param name="action">The approval action (Approved or Rejected).</param>
    /// <param name="comments">Optional comments explaining the decision.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<RequestApprovalHistoryDto> SubmitApprovalActionAsync(
        Guid packageId,
        Guid approverId,
        ApprovalAction action,
        string? comments,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves the full approval history for a document package.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<List<RequestApprovalHistoryDto>> GetApprovalHistoryAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves approval history for a specific version of a document package.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="versionNumber">The version number to filter by.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<List<RequestApprovalHistoryDto>> GetApprovalHistoryByVersionAsync(
        Guid packageId,
        int versionNumber,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Adds a comment to a document package.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="userId">The user adding the comment.</param>
    /// <param name="commentText">The comment text.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<RequestCommentDto> AddCommentAsync(
        Guid packageId,
        Guid userId,
        string commentText,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all comments for a document package.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<List<RequestCommentDto>> GetCommentsAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Handles resubmission of a rejected package. Increments version number
    /// and records a Resubmitted action in approval history.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="userId">The agency user resubmitting.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task ResubmitPackageAsync(
        Guid packageId,
        Guid userId,
        CancellationToken cancellationToken = default);
}
