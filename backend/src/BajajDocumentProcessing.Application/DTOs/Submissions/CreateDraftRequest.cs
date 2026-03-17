using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Request to create a draft submission from the conversational flow
/// </summary>
public class CreateDraftRequest
{
    /// <summary>
    /// PO ID selected during conversational submission
    /// </summary>
    [Required(ErrorMessage = "PO ID is required")]
    [JsonPropertyName("poId")]
    public Guid PoId { get; set; }

    /// <summary>
    /// Agency ID creating the draft
    /// </summary>
    [Required(ErrorMessage = "Agency ID is required")]
    [JsonPropertyName("agencyId")]
    public Guid AgencyId { get; set; }
}
