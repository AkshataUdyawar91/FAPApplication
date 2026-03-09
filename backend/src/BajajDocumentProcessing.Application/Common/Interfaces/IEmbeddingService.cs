namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating text embeddings using Azure OpenAI
/// </summary>
public interface IEmbeddingService
{
    /// <summary>
    /// Generates a vector embedding for a single text string
    /// </summary>
    /// <param name="text">Text to generate embedding for</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Float array representing the text embedding vector</returns>
    Task<float[]> GenerateEmbeddingAsync(string text, CancellationToken cancellationToken = default);

    /// <summary>
    /// Generates vector embeddings for multiple text strings in batch
    /// </summary>
    /// <param name="texts">Collection of texts to generate embeddings for</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of float arrays representing the text embedding vectors</returns>
    Task<List<float[]>> GenerateEmbeddingsAsync(IEnumerable<string> texts, CancellationToken cancellationToken = default);
}
