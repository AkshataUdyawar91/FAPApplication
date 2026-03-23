using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Request to create a draft submission. Both fields are optional — the agency is
/// resolved from the authenticated user's token, and the PO can be selected later
/// in the upload flow.
/// </summary>
public class CreateDraftRequest
{
    /// <summary>
    /// Optional PO ID to pre-select. If omitted, the user selects a PO in the upload flow.
    /// </summary>
    [JsonPropertyName("poId")]
    public Guid? PoId { get; set; }

    /// <summary>
    /// Optional agency ID override. If omitted, the authenticated user's agency is used.
    /// </summary>
    [JsonPropertyName("agencyId")]
    public Guid? AgencyId { get; set; }
}
