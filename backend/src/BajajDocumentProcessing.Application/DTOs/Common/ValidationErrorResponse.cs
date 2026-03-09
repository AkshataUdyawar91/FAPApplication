using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Common;

/// <summary>
/// Error response returned when request validation fails, includes field-level error details
/// </summary>
public class ValidationErrorResponse : ErrorResponse
{
    /// <summary>
    /// Dictionary of field names to their validation error messages
    /// </summary>
    /// <example>
    /// {
    ///   "email": ["Email is required", "Email format is invalid"],
    ///   "amount": ["Amount must be greater than 0"]
    /// }
    /// </example>
    [JsonPropertyName("errors")]
    public required Dictionary<string, string[]> Errors { get; init; }
}
