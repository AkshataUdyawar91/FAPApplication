using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Null implementation of IEmbeddingService when Azure AI Search is not configured
/// </summary>
public class NullEmbeddingService : IEmbeddingService
{
    private readonly ILogger<NullEmbeddingService> _logger;

    public NullEmbeddingService(ILogger<NullEmbeddingService> logger)
    {
        _logger = logger;
    }

    public Task<float[]> GenerateEmbeddingAsync(string text, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Embedding generation skipped - Azure AI Search not configured");
        return Task.FromResult(Array.Empty<float>());
    }

    public Task<List<float[]>> GenerateEmbeddingsAsync(IEnumerable<string> texts, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Embeddings generation skipped - Azure AI Search not configured");
        return Task.FromResult(new List<float[]>());
    }
}
