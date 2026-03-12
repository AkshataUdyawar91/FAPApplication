using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Agency;

/// <summary>
/// Request DTO for creating a new agency.
/// </summary>
public class CreateAgencyRequest
{
    /// <summary>
    /// Unique supplier code identifier. Must be unique across all agencies.
    /// </summary>
    [Required(ErrorMessage = "Supplier code is required.")]
    [StringLength(50, MinimumLength = 1, ErrorMessage = "Supplier code must be between 1 and 50 characters.")]
    [JsonPropertyName("supplierCode")]
    public required string SupplierCode { get; init; }

    /// <summary>
    /// Agency/supplier display name.
    /// </summary>
    [Required(ErrorMessage = "Supplier name is required.")]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "Supplier name must be between 1 and 200 characters.")]
    [JsonPropertyName("supplierName")]
    public required string SupplierName { get; init; }
}
