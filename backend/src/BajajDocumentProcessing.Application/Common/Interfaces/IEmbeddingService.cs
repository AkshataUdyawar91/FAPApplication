namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IEmbeddingService
{
    Task<float[]> GenerateEmbeddingAsync(string text, CancellationToken cancellationToken = default);
    Task<List<float[]>> GenerateEmbeddingsAsync(IEnumerable<string> texts, CancellationToken cancellationToken = default);
}
