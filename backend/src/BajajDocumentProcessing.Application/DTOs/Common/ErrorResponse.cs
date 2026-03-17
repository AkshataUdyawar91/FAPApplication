using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Common;

/// <summary>
/// Standard error response returned by the API for all error scenarios
/// </summary>
public class ErrorResponse
{
    /// <summary>
    /// Unique correlation ID for tracing the request across services
    /// </summary>
    [JsonPropertyName("correlationId")]
    public required string CorrelationId { get; init; }
    
    /// <summary>
    /// User-friendly error message describing what went wrong
    /// </summary>
    [JsonPropertyName("message")]
    public required string Message { get; init; }
    
    /// <summary>
    /// HTTP status code for the error
    /// </summary>
    [JsonPropertyName("statusCode")]
    public required int StatusCode { get; init; }
    
    /// <summary>
    /// UTC timestamp when the error occurred
    /// </summary>
    [JsonPropertyName("timestamp")]
    public required DateTime Timestamp { get; init; }
}
