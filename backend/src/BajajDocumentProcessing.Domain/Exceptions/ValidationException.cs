namespace BajajDocumentProcessing.Domain.Exceptions;

/// <summary>
/// Exception thrown when validation of user input or business rules fails
/// </summary>
/// <remarks>
/// This exception contains a dictionary of field-level validation errors
/// that can be returned to the client for display.
/// Maps to HTTP 400 Bad Request in the API layer.
/// </remarks>
public class ValidationException : Exception
{
    /// <summary>
    /// Gets the dictionary of validation errors keyed by field name
    /// </summary>
    /// <remarks>
    /// Each key represents a field name, and the value is an array of error messages for that field.
    /// Example: { "Email": ["Email is required", "Email format is invalid"] }
    /// </remarks>
    public Dictionary<string, string[]> Errors { get; }

    /// <summary>
    /// Initializes a new instance of the <see cref="ValidationException"/> class with validation errors
    /// </summary>
    /// <param name="errors">Dictionary of field-level validation errors</param>
    public ValidationException(Dictionary<string, string[]> errors)
        : base("One or more validation errors occurred")
    {
        Errors = errors ?? new Dictionary<string, string[]>();
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ValidationException"/> class with a single error message
    /// </summary>
    /// <param name="message">The validation error message</param>
    public ValidationException(string message)
        : base(message)
    {
        Errors = new Dictionary<string, string[]>();
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ValidationException"/> class with a single field error
    /// </summary>
    /// <param name="field">The field name that failed validation</param>
    /// <param name="errorMessage">The validation error message for the field</param>
    public ValidationException(string field, string errorMessage)
        : base($"Validation failed for field '{field}'")
    {
        Errors = new Dictionary<string, string[]>
        {
            { field, new[] { errorMessage } }
        };
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ValidationException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    /// <param name="innerException">The exception that is the cause of the current exception</param>
    public ValidationException(string message, Exception innerException)
        : base(message, innerException)
    {
        Errors = new Dictionary<string, string[]>();
    }
}
