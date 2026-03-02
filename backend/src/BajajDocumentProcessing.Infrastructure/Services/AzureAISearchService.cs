using Azure;
using Azure.Search.Documents;
using Azure.Search.Documents.Indexes;
using Azure.Search.Documents.Indexes.Models;
using Azure.Search.Documents.Models;
using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class AzureAISearchService : IVectorSearchService
{
    private readonly SearchIndexClient _indexClient;
    private readonly SearchClient _searchClient;
    private readonly ILogger<AzureAISearchService> _logger;
    private readonly string _indexName;
    private const int VectorDimensions = 1536; // text-embedding-ada-002 dimensions

    public AzureAISearchService(
        IConfiguration configuration,
        ILogger<AzureAISearchService> logger)
    {
        var endpoint = configuration["AzureAISearch:Endpoint"] 
            ?? throw new InvalidOperationException("AzureAISearch:Endpoint not configured");
        var apiKey = configuration["AzureAISearch:ApiKey"] 
            ?? throw new InvalidOperationException("AzureAISearch:ApiKey not configured");
        _indexName = configuration["AzureAISearch:IndexName"] ?? "analytics-embeddings";

        var credential = new AzureKeyCredential(apiKey);
        _indexClient = new SearchIndexClient(new Uri(endpoint), credential);
        _searchClient = _indexClient.GetSearchClient(_indexName);
        _logger = logger;
    }

    public async Task InitializeIndexAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Initializing Azure AI Search index: {IndexName}", _indexName);

            var fieldBuilder = new FieldBuilder();
            var searchFields = fieldBuilder.Build(typeof(SearchDocument));

            var definition = new SearchIndex(_indexName)
            {
                Fields =
                {
                    new SearchField("id", SearchFieldDataType.String) { IsKey = true, IsFilterable = true },
                    new SearchField("content", SearchFieldDataType.String) { IsSearchable = true },
                    new SearchField("contentVector", SearchFieldDataType.Collection(SearchFieldDataType.Single))
                    {
                        IsSearchable = true,
                        VectorSearchDimensions = VectorDimensions,
                        VectorSearchProfileName = "vector-profile"
                    },
                    new SearchField("state", SearchFieldDataType.String) { IsFilterable = true, IsFacetable = true },
                    new SearchField("timeRange", SearchFieldDataType.String) { IsFilterable = true, IsFacetable = true },
                    new SearchField("submissionCount", SearchFieldDataType.Int32) { IsFilterable = true },
                    new SearchField("approvalRate", SearchFieldDataType.Double) { IsFilterable = true },
                    new SearchField("avgConfidence", SearchFieldDataType.Double) { IsFilterable = true },
                    new SearchField("campaigns", SearchFieldDataType.Collection(SearchFieldDataType.String)) { IsFilterable = true, IsFacetable = true }
                },
                VectorSearch = new VectorSearch
                {
                    Profiles =
                    {
                        new VectorSearchProfile("vector-profile", "vector-config")
                    },
                    Algorithms =
                    {
                        new HnswAlgorithmConfiguration("vector-config")
                    }
                }
            };

            await _indexClient.CreateOrUpdateIndexAsync(definition, cancellationToken: cancellationToken);
            _logger.LogInformation("Azure AI Search index initialized successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Azure AI Search index");
            throw;
        }
    }

    public async Task<List<VectorSearchResult>> SearchAsync(
        float[] queryEmbedding,
        int topK = 5,
        VectorSearchFilter? filter = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var vectorQuery = new VectorizedQuery(queryEmbedding)
            {
                KNearestNeighborsCount = topK,
                Fields = { "contentVector" }
            };

            var searchOptions = new SearchOptions
            {
                VectorSearch = new()
                {
                    Queries = { vectorQuery }
                },
                Size = topK
            };

            // Apply filters
            if (filter != null)
            {
                var filterExpressions = new List<string>();

                if (!string.IsNullOrEmpty(filter.State))
                {
                    filterExpressions.Add($"state eq '{filter.State}'");
                }

                if (!string.IsNullOrEmpty(filter.TimeRange))
                {
                    filterExpressions.Add($"timeRange eq '{filter.TimeRange}'");
                }

                if (filter.States?.Any() == true)
                {
                    var stateFilter = string.Join(" or ", filter.States.Select(s => $"state eq '{s}'"));
                    filterExpressions.Add($"({stateFilter})");
                }

                if (filter.Campaigns?.Any() == true)
                {
                    var campaignFilters = filter.Campaigns.Select(c => $"campaigns/any(campaign: campaign eq '{c}')");
                    filterExpressions.Add($"({string.Join(" or ", campaignFilters)})");
                }

                if (filterExpressions.Any())
                {
                    searchOptions.Filter = string.Join(" and ", filterExpressions);
                }
            }

            var response = await _searchClient.SearchAsync<SearchDocument>(null, searchOptions, cancellationToken);

            var results = new List<VectorSearchResult>();
            await foreach (var result in response.Value.GetResultsAsync())
            {
                var doc = result.Document;
                results.Add(new VectorSearchResult
                {
                    Id = doc.TryGetValue("id", out var id) ? id?.ToString() ?? string.Empty : string.Empty,
                    Content = doc.TryGetValue("content", out var content) ? content?.ToString() ?? string.Empty : string.Empty,
                    Metadata = new VectorMetadata
                    {
                        State = doc.TryGetValue("state", out var state) ? state?.ToString() : null,
                        TimeRange = doc.TryGetValue("timeRange", out var timeRange) ? timeRange?.ToString() : null,
                        SubmissionCount = doc.TryGetValue("submissionCount", out var subCount) ? Convert.ToInt32(subCount) : null,
                        ApprovalRate = doc.TryGetValue("approvalRate", out var appRate) ? Convert.ToDouble(appRate) : null,
                        AvgConfidence = doc.TryGetValue("avgConfidence", out var avgConf) ? Convert.ToDouble(avgConf) : null,
                        Campaigns = doc.TryGetValue("campaigns", out var campaigns) ? 
                            (campaigns as IEnumerable<object>)?.Select(c => c.ToString() ?? string.Empty).ToList() : null
                    },
                    Score = result.Score ?? 0
                });
            }

            _logger.LogInformation("Vector search completed. Found {Count} results", results.Count);
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Vector search failed");
            throw;
        }
    }

    public async Task UpsertDocumentAsync(VectorDocument document, CancellationToken cancellationToken = default)
    {
        await UpsertDocumentsAsync(new[] { document }, cancellationToken);
    }

    public async Task UpsertDocumentsAsync(IEnumerable<VectorDocument> documents, CancellationToken cancellationToken = default)
    {
        try
        {
            var searchDocuments = documents.Select(doc =>
            {
                var searchDoc = new SearchDocument
                {
                    ["id"] = doc.Id,
                    ["content"] = doc.Content,
                    ["contentVector"] = doc.ContentVector,
                    ["state"] = doc.Metadata.State,
                    ["timeRange"] = doc.Metadata.TimeRange,
                    ["submissionCount"] = doc.Metadata.SubmissionCount,
                    ["approvalRate"] = doc.Metadata.ApprovalRate,
                    ["avgConfidence"] = doc.Metadata.AvgConfidence,
                    ["campaigns"] = doc.Metadata.Campaigns
                };
                return searchDoc;
            }).ToList();

            var batch = IndexDocumentsBatch.Upload(searchDocuments);
            await _searchClient.IndexDocumentsAsync(batch, cancellationToken: cancellationToken);

            _logger.LogInformation("Upserted {Count} documents to vector index", searchDocuments.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to upsert documents to vector index");
            throw;
        }
    }

    public async Task DeleteDocumentAsync(string documentId, CancellationToken cancellationToken = default)
    {
        try
        {
            var batch = IndexDocumentsBatch.Delete("id", new[] { documentId });
            await _searchClient.IndexDocumentsAsync(batch, cancellationToken: cancellationToken);

            _logger.LogInformation("Deleted document {DocumentId} from vector index", documentId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete document from vector index");
            throw;
        }
    }
}
