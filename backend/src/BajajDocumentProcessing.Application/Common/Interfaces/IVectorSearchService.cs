namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IVectorSearchService
{
    Task InitializeIndexAsync(CancellationToken cancellationToken = default);
    Task<List<VectorSearchResult>> SearchAsync(float[] queryEmbedding, int topK = 5, VectorSearchFilter? filter = null, CancellationToken cancellationToken = default);
    Task UpsertDocumentAsync(VectorDocument document, CancellationToken cancellationToken = default);
    Task UpsertDocumentsAsync(IEnumerable<VectorDocument> documents, CancellationToken cancellationToken = default);
    Task DeleteDocumentAsync(string documentId, CancellationToken cancellationToken = default);
}

public class VectorDocument
{
    public string Id { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public float[] ContentVector { get; set; } = Array.Empty<float>();
    public VectorMetadata Metadata { get; set; } = new();
}

public class VectorMetadata
{
    public string? State { get; set; }
    public string? TimeRange { get; set; }
    public int? SubmissionCount { get; set; }
    public double? ApprovalRate { get; set; }
    public double? AvgConfidence { get; set; }
    public List<string>? Campaigns { get; set; }
}

public class VectorSearchResult
{
    public string Id { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public VectorMetadata Metadata { get; set; } = new();
    public double Score { get; set; }
}

public class VectorSearchFilter
{
    public string? State { get; set; }
    public string? TimeRange { get; set; }
    public List<string>? States { get; set; }
    public List<string>? Campaigns { get; set; }
}
