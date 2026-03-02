using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating approval recommendations with evidence
/// </summary>
public interface IRecommendationAgent
{
    /// <summary>
    /// Generates a recommendation for a document package based on validation results and confidence score
    /// </summary>
    /// <param name="packageId">The package ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The generated recommendation</returns>
    Task<Recommendation> GenerateRecommendationAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
