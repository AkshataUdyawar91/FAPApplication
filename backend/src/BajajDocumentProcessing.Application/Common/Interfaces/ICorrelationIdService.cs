namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for accessing the correlation ID for the current request
/// </summary>
/// <remarks>
/// The correlation ID is a unique identifier that tracks a request through all layers
/// of the application. It is used for logging, tracing, and debugging purposes.
/// The correlation ID is set by the CorrelationIdMiddleware and stored in HttpContext.Items.
/// </remarks>
public interface ICorrelationIdService
{
    /// <summary>
    /// Gets the correlation ID for the current request
    /// </summary>
    /// <returns>
    /// The correlation ID as a string, or "no-correlation-id" if not available
    /// </returns>
    /// <remarks>
    /// This method retrieves the correlation ID from HttpContext.Items where it was
    /// stored by the CorrelationIdMiddleware. If the correlation ID is not found
    /// (which should not happen in normal operation), it returns a fallback value.
    /// </remarks>
    string GetCorrelationId();
}
