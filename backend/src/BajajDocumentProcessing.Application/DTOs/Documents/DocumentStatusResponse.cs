using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Response for document extraction status polling
/// </summary>
public class DocumentStatusResponse
{
    /// <summary>
    /// Extraction status: Pending, Processing, Completed, Failed
    /// </summary>
    [JsonPropertyName("status")]
    public string Status { get; set; } = "Pending";

    /// <summary>
    /// UTC timestamp when extraction completed (null if not yet completed)
    /// </summary>
    [JsonPropertyName("extractedAt")]
    public DateTime? ExtractedAt { get; set; }

    /// <summary>
    /// Error message if extraction failed
    /// </summary>
    [JsonPropertyName("error")]
    public string? Error { get; set; }
}
