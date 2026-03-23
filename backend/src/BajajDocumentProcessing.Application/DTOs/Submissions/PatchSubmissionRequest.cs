using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Request to patch submission fields. All fields are optional — only provided fields are applied.
/// </summary>
public class PatchSubmissionRequest
{
    /// <summary>
    /// Activity state/region where the work was performed (e.g., Maharashtra).
    /// </summary>
    [JsonPropertyName("state")]
    public string? State { get; set; }

    /// <summary>
    /// PO ID to associate with this draft submission.
    /// </summary>
    [JsonPropertyName("selectedPOId")]
    public Guid? SelectedPOId { get; set; }
}
