namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for validating user input to prevent prompt injection and malicious queries
/// </summary>
public interface IInputGuardrailService
{
    /// <summary>
    /// Validates user input for security threats and policy violations
    /// </summary>
    /// <param name="query">User input query to validate</param>
    /// <param name="userId">User's unique identifier</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async validation operation</returns>
    /// <exception cref="InputValidationException">Thrown when input fails validation</exception>
    Task ValidateInputAsync(string query, Guid userId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Exception thrown when user input fails validation
/// </summary>
public class InputValidationException : Exception
{
    /// <summary>
    /// Initializes a new instance of the InputValidationException class
    /// </summary>
    /// <param name="message">Error message describing the validation failure</param>
    public InputValidationException(string message) : base(message) { }
}
