namespace BajajDocumentProcessing.Domain.Exceptions;

/// <summary>
/// Exception thrown when a requested resource is not found in the system
/// </summary>
/// <remarks>
/// This exception should be thrown when attempting to retrieve an entity by ID
/// or other unique identifier that does not exist in the database.
/// Maps to HTTP 404 Not Found in the API layer.
/// </remarks>
public class NotFoundException : Exception
{
    /// <summary>
    /// Initializes a new instance of the <see cref="NotFoundException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    public NotFoundException(string message) : base(message)
    {
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="NotFoundException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    /// <param name="innerException">The exception that is the cause of the current exception</param>
    public NotFoundException(string message, Exception innerException) 
        : base(message, innerException)
    {
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="NotFoundException"/> class with a default message
    /// </summary>
    public NotFoundException() : base("The requested resource was not found")
    {
    }
}
