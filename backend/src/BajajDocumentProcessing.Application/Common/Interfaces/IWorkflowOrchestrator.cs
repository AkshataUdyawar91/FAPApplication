namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Orchestrates the document processing workflow across multiple agents
/// </summary>
public interface IWorkflowOrchestrator
{
    /// <summary>
    /// Processes a document submission through the complete workflow
    /// </summary>
    /// <param name="packageId">The document package ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if processing completed successfully</returns>
    Task<bool> ProcessSubmissionAsync(Guid packageId, CancellationToken cancellationToken = default);
}
