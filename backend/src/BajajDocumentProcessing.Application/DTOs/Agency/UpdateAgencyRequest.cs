using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Agency;

/// <summary>Request DTO for updating an agency — only name is editable.</summary>
public class UpdateAgencyRequest
{
    [Required, StringLength(200, MinimumLength = 1)]
    public string SupplierName { get; set; } = string.Empty;
}
