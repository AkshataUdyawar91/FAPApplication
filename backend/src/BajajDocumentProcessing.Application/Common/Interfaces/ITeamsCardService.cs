using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Builds Adaptive Card JSON from templates and data context.
/// </summary>
public interface ITeamsCardService
{
    /// <summary>
    /// Populates the new-submission adaptive card template with submission data.
    /// Returns the expanded card JSON string.
    /// </summary>
    /// <param name="data">The submission card data containing all token values for the template.</param>
    /// <returns>The expanded Adaptive Card JSON string.</returns>
    string BuildNewSubmissionCard(SubmissionCardData data);

    /// <summary>
    /// Populates the review-details adaptive card template with validation breakdown data.
    /// Returns the expanded card JSON string.
    /// </summary>
    /// <param name="data">The validation breakdown data containing check groups and status.</param>
    /// <returns>The expanded Adaptive Card JSON string.</returns>
    string BuildReviewDetailsCard(ValidationBreakdownData data);
}
