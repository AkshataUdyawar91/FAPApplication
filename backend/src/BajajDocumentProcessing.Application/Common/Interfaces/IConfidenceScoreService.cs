namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for calculating confidence scores for document packages
/// </summary>
public interface IConfidenceScoreService
{
    /// <summary>
    /// Calculates the overall confidence score for a document package
    /// </summary>
    /// <param name="packageId">The package ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The calculated confidence score entity</returns>
    Task<Domain.Entities.ConfidenceScore> CalculateConfidenceScoreAsync(
        Guid packageId, 
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Calculates weighted confidence score from individual document confidences
    /// </summary>
    /// <param name="poConfidence">PO confidence (0-100)</param>
    /// <param name="invoiceConfidence">Invoice confidence (0-100)</param>
    /// <param name="costSummaryConfidence">Cost Summary confidence (0-100)</param>
    /// <param name="activityConfidence">Activity confidence (0-100)</param>
    /// <param name="photosConfidence">Photos confidence (0-100)</param>
    /// <returns>Overall weighted confidence score (0-100)</returns>
    double CalculateWeightedScore(
        double poConfidence,
        double invoiceConfidence,
        double costSummaryConfidence,
        double activityConfidence,
        double photosConfidence);
}
