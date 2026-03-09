using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Represents a single submission item in a paginated list
/// </summary>
public class SubmissionListItemDto
{
    /// <summary>
    /// Unique identifier of the submission
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }
    
    /// <summary>
    /// Current state of the submission (Uploaded, Extracting, Validating, etc.)
    /// </summary>
    [JsonPropertyName("state")]
    public required string State { get; init; }
    
    /// <summary>
    /// UTC timestamp when the submission was created
    /// </summary>
    [JsonPropertyName("createdAt")]
    public required DateTime CreatedAt { get; init; }
    
    /// <summary>
    /// UTC timestamp when the submission was last updated
    /// </summary>
    [JsonPropertyName("updatedAt")]
    public DateTime? UpdatedAt { get; init; }
    
    /// <summary>
    /// Number of documents in the submission
    /// </summary>
    [JsonPropertyName("documentCount")]
    public required int DocumentCount { get; init; }
    
    /// <summary>
    /// Invoice number extracted from the invoice document
    /// </summary>
    [JsonPropertyName("invoiceNumber")]
    public string? InvoiceNumber { get; init; }
    
    /// <summary>
    /// Invoice amount extracted from the invoice document
    /// </summary>
    [JsonPropertyName("invoiceAmount")]
    public decimal? InvoiceAmount { get; init; }
    
    /// <summary>
    /// PO number extracted from the PO document
    /// </summary>
    [JsonPropertyName("poNumber")]
    public string? PoNumber { get; init; }
    
    /// <summary>
    /// PO amount extracted from the PO document
    /// </summary>
    [JsonPropertyName("poAmount")]
    public decimal? PoAmount { get; init; }
    
    /// <summary>
    /// Overall AI confidence score (0-100)
    /// </summary>
    [JsonPropertyName("overallConfidence")]
    public decimal? OverallConfidence { get; init; }
}
