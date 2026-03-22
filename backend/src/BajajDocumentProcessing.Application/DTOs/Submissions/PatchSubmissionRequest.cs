using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Request to patch submission fields (e.g., state selection, PO selection)
/// </summary>
public class PatchSubmissionRequest
{
    /// <summary>
    /// Activity state/region where the work was performed
    /// </summary>
    [StringLength(100, ErrorMessage = "State cannot exceed 100 characters")]
    [JsonPropertyName("state")]
    public string? State { get; set; }

    /// <summary>
    /// Selected PO ID to link to this submission
    /// </summary>
    [JsonPropertyName("selectedPOId")]
    public Guid? SelectedPOId { get; set; }
}
