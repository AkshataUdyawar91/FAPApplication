using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for running proactive (on-upload) field presence validation on a single document.
/// Reuses existing field presence checks from the reactive validation pipeline.
/// </summary>
public interface IProactiveValidator
{
    /// <summary>
    /// Validates a single document's field presence immediately after upload and extraction.
    /// Does NOT run cross-document or SAP validation (those remain in the reactive flow).
    /// </summary>
    /// <param name="documentId">The ID of the document to validate</param>
    /// <param name="documentType">The type of document being validated</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Proactive validation result with missing fields and warnings</returns>
    Task<ProactiveValidationResult> ValidateDocumentOnUploadAsync(
        Guid documentId,
        DocumentType documentType,
        CancellationToken cancellationToken = default);
}
