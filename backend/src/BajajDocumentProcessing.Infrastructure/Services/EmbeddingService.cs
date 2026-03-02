using Azure;
using Azure.AI.OpenAI;
using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class EmbeddingService : IEmbeddingService
{
    private readonly OpenAIClient _client;
    private readonly ILogger<EmbeddingService> _logger;
    private readonly string _deploymentName;

    public EmbeddingService(
        IConfiguration configuration,
        ILogger<EmbeddingService> logger)
    {
        var endpoint = configuration["AzureOpenAI:Endpoint"] 
            ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] 
            ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        _deploymentName = configuration["AzureOpenAI:EmbeddingDeploymentName"] ?? "text-embedding-ada-002";

        _client = new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
        _logger = logger;
    }

    public async Task<float[]> GenerateEmbeddingAsync(string text, CancellationToken cancellationToken = default)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                throw new ArgumentException("Text cannot be null or empty", nameof(text));
            }

            var options = new EmbeddingsOptions(_deploymentName, new[] { text });
            var response = await _client.GetEmbeddingsAsync(options, cancellationToken);

            var embedding = response.Value.Data[0].Embedding.ToArray();
            _logger.LogDebug("Generated embedding with {Dimensions} dimensions", embedding.Length);

            return embedding;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate embedding for text");
            throw;
        }
    }

    public async Task<List<float[]>> GenerateEmbeddingsAsync(IEnumerable<string> texts, CancellationToken cancellationToken = default)
    {
        try
        {
            var textList = texts.ToList();
            if (!textList.Any())
            {
                return new List<float[]>();
            }

            if (textList.Any(string.IsNullOrWhiteSpace))
            {
                throw new ArgumentException("All texts must be non-null and non-empty", nameof(texts));
            }

            var options = new EmbeddingsOptions(_deploymentName, textList);
            var response = await _client.GetEmbeddingsAsync(options, cancellationToken);

            var embeddings = response.Value.Data
                .OrderBy(d => d.Index)
                .Select(d => d.Embedding.ToArray())
                .ToList();

            _logger.LogInformation("Generated {Count} embeddings", embeddings.Count);

            return embeddings;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate embeddings for texts");
            throw;
        }
    }
}
