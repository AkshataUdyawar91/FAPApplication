using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Agency;

/// <summary>
/// DTO representing an agency/supplier entity.
/// </summary>
public class AgencyDto
{
    /// <summary>
    /// Unique identifier of the agency.
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }

    /// <summary>
    /// Unique supplier code identifier.
    /// </summary>
    [JsonPropertyName("supplierCode")]
    public required string SupplierCode { get; init; }

    /// <summary>
    /// Agency/supplier display name.
    /// </summary>
    [JsonPropertyName("supplierName")]
    public required string SupplierName { get; init; }

    /// <summary>
    /// UTC timestamp when the agency was created.
    /// </summary>
    [JsonPropertyName("createdAt")]
    public required DateTime CreatedAt { get; init; }
}
