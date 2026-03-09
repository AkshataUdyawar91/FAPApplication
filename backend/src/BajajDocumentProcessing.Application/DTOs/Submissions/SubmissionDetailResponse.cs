using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Detailed information about a single submission
/// </summary>
public class SubmissionDetailResponse
{
    /// <summary>
    /// Unique identifier of the submission
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }
    
    /// <summary>
    /// Current state of the submission
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
    /// UTC timestamp when ASM reviewed the submission
    /// </summary>
    [JsonPropertyName("asmReviewedAt")]
    public DateTime? ASMReviewedAt { get; init; }
    
    /// <summary>
    /// ASM review notes
    /// </summary>
    [JsonPropertyName("asmReviewNotes")]
    public string? ASMReviewNotes { get; init; }
    
    /// <summary>
    /// UTC timestamp when HQ reviewed the submission
    /// </summary>
    [JsonPropertyName("hqReviewedAt")]
    public DateTime? HQReviewedAt { get; init; }
    
    /// <summary>
    /// HQ review notes
    /// </summary>
    [JsonPropertyName("hqReviewNotes")]
    public string? HQReviewNotes { get; init; }
    
    /// <summary>
    /// Legacy: UTC timestamp when the submission was reviewed
    /// </summary>
    [JsonPropertyName("reviewedAt")]
    public DateTime? ReviewedAt { get; init; }
    
    /// <summary>
    /// Legacy: Review notes
    /// </summary>
    [JsonPropertyName("reviewNotes")]
    public string? ReviewNotes { get; init; }
    
    /// <summary>
    /// List of documents in the submission
    /// </summary>
    [JsonPropertyName("documents")]
    public required List<SubmissionDocumentDto> Documents { get; init; }
    
    /// <summary>
    /// Validation results
    /// </summary>
    [JsonPropertyName("validationResult")]
    public ValidationResultDto? ValidationResult { get; init; }
    
    /// <summary>
    /// Confidence scores
    /// </summary>
    [JsonPropertyName("confidenceScore")]
    public ConfidenceScoreDto? ConfidenceScore { get; init; }
    
    /// <summary>
    /// AI recommendation
    /// </summary>
    [JsonPropertyName("recommendation")]
    public RecommendationDto? Recommendation { get; init; }
}

/// <summary>
/// Document information within a submission detail response
/// </summary>
public class SubmissionDocumentDto
{
    /// <summary>
    /// Unique identifier of the document
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }
    
    /// <summary>
    /// Type of document
    /// </summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }
    
    /// <summary>
    /// Original filename
    /// </summary>
    [JsonPropertyName("filename")]
    public required string Filename { get; init; }
    
    /// <summary>
    /// Blob storage URL
    /// </summary>
    [JsonPropertyName("blobUrl")]
    public required string BlobUrl { get; init; }
    
    /// <summary>
    /// Extraction confidence score
    /// </summary>
    [JsonPropertyName("extractionConfidence")]
    public double? ExtractionConfidence { get; init; }
    
    /// <summary>
    /// Extracted data as JSON string
    /// </summary>
    [JsonPropertyName("extractedData")]
    public string? ExtractedData { get; init; }
}

/// <summary>
/// Validation result information
/// </summary>
public class ValidationResultDto
{
    /// <summary>
    /// Whether all validations passed
    /// </summary>
    [JsonPropertyName("allValidationsPassed")]
    public required bool AllValidationsPassed { get; init; }
    
    /// <summary>
    /// Failure reason if validations failed
    /// </summary>
    [JsonPropertyName("failureReason")]
    public string? FailureReason { get; init; }
}

/// <summary>
/// Confidence score information
/// </summary>
public class ConfidenceScoreDto
{
    /// <summary>
    /// Overall confidence score (0-100)
    /// </summary>
    [JsonPropertyName("overallConfidence")]
    public required double OverallConfidence { get; init; }
    
    /// <summary>
    /// PO document confidence score
    /// </summary>
    [JsonPropertyName("poConfidence")]
    public double? PoConfidence { get; init; }
    
    /// <summary>
    /// Invoice document confidence score
    /// </summary>
    [JsonPropertyName("invoiceConfidence")]
    public double? InvoiceConfidence { get; init; }
    
    /// <summary>
    /// Cost summary document confidence score
    /// </summary>
    [JsonPropertyName("costSummaryConfidence")]
    public double? CostSummaryConfidence { get; init; }
    
    /// <summary>
    /// Activity document confidence score
    /// </summary>
    [JsonPropertyName("activityConfidence")]
    public double? ActivityConfidence { get; init; }
    
    /// <summary>
    /// Photos confidence score
    /// </summary>
    [JsonPropertyName("photosConfidence")]
    public double? PhotosConfidence { get; init; }
}

/// <summary>
/// Recommendation information
/// </summary>
public class RecommendationDto
{
    /// <summary>
    /// Recommendation type (Approve, Review, Reject)
    /// </summary>
    [JsonPropertyName("type")]
    public required string Type { get; init; }
    
    /// <summary>
    /// Evidence supporting the recommendation
    /// </summary>
    [JsonPropertyName("evidence")]
    public string? Evidence { get; init; }
}
