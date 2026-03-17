using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.ASM;

/// <summary>
/// DTO representing an Area Sales Manager.
/// </summary>
public class ASMDto
{
    /// <summary>
    /// Unique identifier of the ASM.
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }

    /// <summary>
    /// Full name of the ASM.
    /// </summary>
    [JsonPropertyName("name")]
    public required string Name { get; init; }

    /// <summary>
    /// Geographic area/region assigned to this ASM.
    /// </summary>
    [JsonPropertyName("location")]
    public required string Location { get; init; }

    /// <summary>
    /// Optional linked user account ID.
    /// </summary>
    [JsonPropertyName("userId")]
    public Guid? UserId { get; init; }
}
