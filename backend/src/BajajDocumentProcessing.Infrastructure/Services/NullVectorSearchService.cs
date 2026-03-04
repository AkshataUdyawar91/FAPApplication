using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Null implementation of IVectorSearchService when Azure AI Search is not configured
/// </summary>
public class NullVectorSearchService : IVectorSearchService
{
    private readonly ILogger<NullVectorSearchService> _logger;

    public NullVectorSearchService(ILogger<NullVectorSearchService> logger)
    {
        _logger = logger;
        _logger.LogWarning("Azure AI Search is not configured. Vector search features are disabled.");
    }

    public Task InitializeIndexAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Azure AI Search not configured - skipping index initialization");
        return Task.CompletedTask;
    }

    public Task<List<VectorSearchResult>> SearchAsync(
        float[] queryEmbedding,
        int topK = 5,
        VectorSearchFilter? filter = null,
        CancellationToken cancellationToken = default)
    {
        _logger.LogWarning("Vector search called but Azure AI Search is not configured");
        return Task.FromResult(new List<VectorSearchResult>());
    }

    public Task UpsertDocumentAsync(VectorDocument document, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Document upsert skipped - Azure AI Search not configured");
        return Task.CompletedTask;
    }

    public Task UpsertDocumentsAsync(IEnumerable<VectorDocument> documents, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Documents upsert skipped - Azure AI Search not configured");
        return Task.CompletedTask;
    }

    public Task DeleteDocumentAsync(string documentId, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Document deletion skipped - Azure AI Search not configured");
        return Task.CompletedTask;
    }
}
