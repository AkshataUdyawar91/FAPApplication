using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Agency;

/// <summary>Request DTO for updating an agency.</summary>
public class UpdateAgencyRequest
{
    [Required, StringLength(50, MinimumLength = 1)]
    public string SupplierCode { get; set; } = string.Empty;

    [Required, StringLength(200, MinimumLength = 1)]
    public string SupplierName { get; set; } = string.Empty;
}
