namespace BajajDocumentProcessing.Domain.Exceptions;

/// <summary>
/// Exception thrown when a user attempts to access a resource they do not have permission to access
/// </summary>
/// <remarks>
/// This exception should be thrown when a user is authenticated but lacks the necessary
/// permissions or ownership rights to perform the requested operation.
/// Maps to HTTP 403 Forbidden in the API layer.
/// </remarks>
public class ForbiddenException : Exception
{
    /// <summary>
    /// Initializes a new instance of the <see cref="ForbiddenException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    public ForbiddenException(string message) : base(message)
    {
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ForbiddenException"/> class
    /// </summary>
    /// <param name="message">The error message that explains the reason for the exception</param>
    /// <param name="innerException">The exception that is the cause of the current exception</param>
    public ForbiddenException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ForbiddenException"/> class with a default message
    /// </summary>
    public ForbiddenException() : base("You do not have permission to access this resource")
    {
    }
}
