using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Request to patch submission fields (e.g., state selection)
/// </summary>
public class PatchSubmissionRequest
{
    /// <summary>
    /// Activity state/region where the work was performed
    /// </summary>
    [Required(ErrorMessage = "State is required")]
    [StringLength(100, ErrorMessage = "State cannot exceed 100 characters")]
    [JsonPropertyName("state")]
    public string State { get; set; } = string.Empty;
}
