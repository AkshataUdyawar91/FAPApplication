using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Represents a document within a submission
/// </summary>
public class DocumentDto
{
    /// <summary>
    /// Unique identifier of the document
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }
    
    /// <summary>
    /// Type of document (PO, Invoice, CostSummary, Photo, AdditionalDocument)
    /// </summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }
    
    /// <summary>
    /// Original filename
    /// </summary>
    [JsonPropertyName("fileName")]
    public required string FileName { get; init; }
    
    /// <summary>
    /// File size in bytes
    /// </summary>
    [JsonPropertyName("fileSize")]
    public required long FileSize { get; init; }
    
    /// <summary>
    /// URL to access the document
    /// </summary>
    [JsonPropertyName("fileUrl")]
    public required string FileUrl { get; init; }
    
    /// <summary>
    /// Current state of the document (Uploaded, Processing, Completed, Failed)
    /// </summary>
    [JsonPropertyName("state")]
    public required string State { get; init; }
    
    /// <summary>
    /// AI confidence score for this document (0-100)
    /// </summary>
    [JsonPropertyName("confidence")]
    public decimal? Confidence { get; init; }
    
    /// <summary>
    /// Extracted data from the document as JSON
    /// </summary>
    [JsonPropertyName("extractedData")]
    public string? ExtractedData { get; init; }
    
    /// <summary>
    /// UTC timestamp when the document was uploaded
    /// </summary>
    [JsonPropertyName("uploadedAt")]
    public required DateTime UploadedAt { get; init; }
}
