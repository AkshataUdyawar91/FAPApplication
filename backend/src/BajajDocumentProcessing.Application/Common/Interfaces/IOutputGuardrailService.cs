namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for validating and sanitizing AI-generated output to prevent data leakage
/// </summary>
public interface IOutputGuardrailService
{
    /// <summary>
    /// Validates and sanitizes AI-generated response against source data
    /// </summary>
    /// <param name="response">AI-generated response to validate</param>
    /// <param name="sourceData">Source data used to generate the response</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Validated and sanitized response text</returns>
    /// <exception cref="OutputValidationException">Thrown when output fails validation</exception>
    Task<string> ValidateAndSanitizeOutputAsync(
        string response, 
        List<VectorSearchResult> sourceData, 
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Exception thrown when AI-generated output fails validation
/// </summary>
public class OutputValidationException : Exception
{
    /// <summary>
    /// Initializes a new instance of the OutputValidationException class
    /// </summary>
    /// <param name="message">Error message describing the validation failure</param>
    public OutputValidationException(string message) : base(message) { }
}
