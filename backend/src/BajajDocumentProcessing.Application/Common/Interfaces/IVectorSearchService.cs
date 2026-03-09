namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing vector search operations with Azure AI Search
/// </summary>
public interface IVectorSearchService
{
    /// <summary>
    /// Initializes the vector search index with schema and configuration
    /// </summary>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async operation</returns>
    Task InitializeIndexAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Performs semantic search using a query embedding vector
    /// </summary>
    /// <param name="queryEmbedding">Query embedding vector</param>
    /// <param name="topK">Number of top results to return (default 5)</param>
    /// <param name="filter">Optional filter to restrict search scope</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of search results ordered by relevance score</returns>
    Task<List<VectorSearchResult>> SearchAsync(float[] queryEmbedding, int topK = 5, VectorSearchFilter? filter = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Inserts or updates a single document in the vector index
    /// </summary>
    /// <param name="document">Vector document to upsert</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async operation</returns>
    Task UpsertDocumentAsync(VectorDocument document, CancellationToken cancellationToken = default);

    /// <summary>
    /// Inserts or updates multiple documents in the vector index in batch
    /// </summary>
    /// <param name="documents">Collection of vector documents to upsert</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async operation</returns>
    Task UpsertDocumentsAsync(IEnumerable<VectorDocument> documents, CancellationToken cancellationToken = default);

    /// <summary>
    /// Deletes a document from the vector index
    /// </summary>
    /// <param name="documentId">ID of the document to delete</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async operation</returns>
    Task DeleteDocumentAsync(string documentId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Vector document for indexing in Azure AI Search
/// </summary>
public class VectorDocument
{
    /// <summary>
    /// Unique identifier for the document
    /// </summary>
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Text content of the document
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Vector embedding of the content
    /// </summary>
    public float[] ContentVector { get; set; } = Array.Empty<float>();

    /// <summary>
    /// Metadata for filtering and faceting
    /// </summary>
    public VectorMetadata Metadata { get; set; } = new();
}

/// <summary>
/// Metadata associated with a vector document
/// </summary>
public class VectorMetadata
{
    /// <summary>
    /// State name for geographic filtering
    /// </summary>
    public string? State { get; set; }

    /// <summary>
    /// Time range description (e.g., "Q1 2024")
    /// </summary>
    public string? TimeRange { get; set; }

    /// <summary>
    /// Number of submissions in this data point
    /// </summary>
    public int? SubmissionCount { get; set; }

    /// <summary>
    /// Approval rate as a percentage (0-100)
    /// </summary>
    public double? ApprovalRate { get; set; }

    /// <summary>
    /// Average confidence score (0-100)
    /// </summary>
    public double? AvgConfidence { get; set; }

    /// <summary>
    /// List of campaign names
    /// </summary>
    public List<string>? Campaigns { get; set; }
}

/// <summary>
/// Result from a vector search query
/// </summary>
public class VectorSearchResult
{
    /// <summary>
    /// Document ID
    /// </summary>
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Document content
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Document metadata
    /// </summary>
    public VectorMetadata Metadata { get; set; } = new();

    /// <summary>
    /// Relevance score (0-1, higher is more relevant)
    /// </summary>
    public double Score { get; set; }
}

/// <summary>
/// Filter for restricting vector search scope
/// </summary>
public class VectorSearchFilter
{
    /// <summary>
    /// Filter by single state
    /// </summary>
    public string? State { get; set; }

    /// <summary>
    /// Filter by time range
    /// </summary>
    public string? TimeRange { get; set; }

    /// <summary>
    /// Filter by multiple states
    /// </summary>
    public List<string>? States { get; set; }

    /// <summary>
    /// Filter by multiple campaigns
    /// </summary>
    public List<string>? Campaigns { get; set; }
}
