using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Assembles strongly-typed DTOs with all token values needed for
/// adaptive card and email template population.
/// </summary>
public interface INotificationDataService
{
    /// <summary>
    /// Loads all submission data needed to populate the adaptive card or email template.
    /// Includes: Package, PO, Teams.Invoices, Teams.Photos, EnquiryDocument,
    /// ConfidenceScore, Recommendation, ValidationResult, Agency.
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A fully populated <see cref="SubmissionCardData"/> DTO.</returns>
    Task<SubmissionCardData> GetSubmissionCardDataAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Loads per-document validation breakdown for the Review Details flow.
    /// Groups validation checks by type (SAP, Amount, LineItem, Completeness, Date, Vendor).
    /// </summary>
    /// <param name="packageId">The document package ID.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A fully populated <see cref="ValidationBreakdownData"/> DTO.</returns>
    Task<ValidationBreakdownData> GetValidationBreakdownAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
