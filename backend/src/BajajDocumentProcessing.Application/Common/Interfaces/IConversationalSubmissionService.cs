using BajajDocumentProcessing.Application.DTOs.Conversation;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Drives the 10-step conversational submission chatbot flow.
/// Maintains per-submission state, persists progress, and returns structured bot responses.
/// </summary>
public interface IConversationalSubmissionService
{
    /// <summary>
    /// Processes a single chat action (button tap, message, file upload confirmation)
    /// and returns the next bot response with buttons/cards.
    /// </summary>
    Task<ConversationResponse> ProcessMessageAsync(
        ConversationRequest request,
        Guid userId,
        Guid agencyId,
        CancellationToken ct = default);

    /// <summary>
    /// Resumes a draft submission from the last completed step.
    /// Loads all previously entered data and returns the appropriate step response.
    /// </summary>
    Task<ConversationResponse> ResumeAsync(
        Guid submissionId,
        Guid userId,
        Guid agencyId,
        CancellationToken ct = default);

    /// <summary>
    /// Returns the current conversation state for a submission (step, progress, etc.).
    /// </summary>
    Task<ConversationResponse> GetStateAsync(
        Guid submissionId,
        CancellationToken ct = default);
}
