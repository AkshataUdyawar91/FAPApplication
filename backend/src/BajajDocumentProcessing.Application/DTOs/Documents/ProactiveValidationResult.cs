using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Result of proactive (on-upload) field presence validation for a single document.
/// </summary>
public class ProactiveValidationResult
{
    /// <summary>
    /// Whether all required fields are present in the document.
    /// True if and only if MissingFields is empty.
    /// </summary>
    public bool Passed { get; set; }

    /// <summary>
    /// The document type that was validated.
    /// </summary>
    public DocumentType DocumentType { get; set; }

    /// <summary>
    /// List of required fields that are missing from the document.
    /// </summary>
    public List<string> MissingFields { get; set; } = new();

    /// <summary>
    /// Non-blocking warnings (e.g., extraction incomplete, low confidence fields).
    /// </summary>
    public List<string> Warnings { get; set; } = new();

    /// <summary>
    /// Timestamp when the validation was performed.
    /// </summary>
    public DateTime ValidatedAt { get; set; }
}
