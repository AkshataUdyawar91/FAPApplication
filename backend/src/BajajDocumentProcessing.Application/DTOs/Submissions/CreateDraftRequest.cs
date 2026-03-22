using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Request to create a draft submission from the conversational flow
/// </summary>
public class CreateDraftRequest
{
    /// <summary>
    /// PO ID selected during conversational submission (optional - can be set later)
    /// </summary>
    [JsonPropertyName("poId")]
    public Guid? PoId { get; set; }

    /// <summary>
    /// Agency ID creating the draft (optional - will use authenticated user's agency)
    /// </summary>
    [JsonPropertyName("agencyId")]
    public Guid? AgencyId { get; set; }
}
