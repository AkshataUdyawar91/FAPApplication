namespace BajajDocumentProcessing.Domain.Exceptions;

/// <summary>
/// Exception thrown when an operation conflicts with the current state of a resource
/// </summary>
/// <remarks>
/// This exception should be thrown when attempting to perform an operation that would
/// violate business rules or create an inconsistent state. Examples include:
/// - Attempting to create a duplicate resource
/// - Attempting to transition to an invalid state
/// - Attempting to modify a resource that has been locked or is in use
/// Maps to HTTP 409 Conflict in the API layer.
/// </remarks>
public class ConflictException : Exception
{
    /// <summary>
    /// Initializes a new instance of the <see cref="ConflictException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    public ConflictException(string message) : base(message)
    {
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ConflictException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    /// <param name="innerException">The exception that is the cause of the current exception</param>
    public ConflictException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ConflictException"/> class with a default message
    /// </summary>
    public ConflictException() : base("The operation conflicts with the current state of the resource")
    {
    }
}
