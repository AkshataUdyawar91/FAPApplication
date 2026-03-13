using BajajDocumentProcessing.Application.DTOs.Conversation;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for running per-document proactive validation immediately after extraction.
/// Returns granular rule-level results for real-time display in the chat UI.
/// Distinct from IValidationAgent which validates the entire package post-submit.
/// </summary>
public interface IProactiveValidationService
{
    /// <summary>
    /// Validates a single document immediately after extraction.
    /// Returns per-rule results for real-time display in the chat UI.
    /// </summary>
    /// <param name="documentId">The document entity ID (Invoice, CostSummary, or ActivitySummary)</param>
    /// <param name="documentType">The type of document being validated</param>
    /// <param name="packageId">The parent DocumentPackage ID for cross-document checks</param>
    /// <param name="ct">Cancellation token</param>
    /// <returns>Validation response with per-rule pass/fail/warning results</returns>
    Task<ProactiveValidationResponse> ValidateDocumentAsync(
        Guid documentId,
        DocumentType documentType,
        Guid packageId,
        CancellationToken ct = default);
}
