using BajajDocumentProcessing.Application.DTOs.Submissions;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating enhanced validation reports with detailed evidence and actionable recommendations
/// </summary>
public interface IEnhancedValidationReportService
{
    /// <summary>
    /// Generates a comprehensive validation report for a document package
    /// </summary>
    /// <param name="packageId">The unique identifier of the package</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Enhanced validation report with detailed evidence</returns>
    Task<EnhancedValidationReportDto> GenerateReportAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
