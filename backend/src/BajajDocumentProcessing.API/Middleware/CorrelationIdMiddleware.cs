using Microsoft.Extensions.Primitives;

namespace BajajDocumentProcessing.API.Middleware;

/// <summary>
/// Middleware that generates or extracts correlation IDs for request tracing
/// </summary>
/// <remarks>
/// This middleware ensures every request has a unique correlation ID that can be used
/// to trace the request through all layers of the application. The correlation ID is:
/// - Extracted from the X-Correlation-ID request header if present
/// - Generated as a new GUID if not present in the request
/// - Stored in HttpContext.Items for access by other middleware and services
/// - Added to the X-Correlation-ID response header for client tracking
/// </remarks>
public class CorrelationIdMiddleware
{
    private readonly RequestDelegate _next;
    private const string CorrelationIdHeader = "X-Correlation-ID";
    private const string CorrelationIdKey = "CorrelationId";

    /// <summary>
    /// Initializes a new instance of the <see cref="CorrelationIdMiddleware"/> class
    /// </summary>
    /// <param name="next">The next middleware in the pipeline</param>
    public CorrelationIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    /// <summary>
    /// Invokes the middleware to process the HTTP request
    /// </summary>
    /// <param name="context">The HTTP context for the current request</param>
    /// <returns>A task representing the asynchronous operation</returns>
    public async Task InvokeAsync(HttpContext context)
    {
        // Try to get correlation ID from request header
        var correlationId = GetCorrelationIdFromHeader(context);

        // If not present, generate a new one
        if (string.IsNullOrEmpty(correlationId))
        {
            correlationId = Guid.NewGuid().ToString();
        }

        // Store in HttpContext.Items for access by other middleware and services
        context.Items[CorrelationIdKey] = correlationId;

        // Add to response header so client can track the request
        context.Response.OnStarting(() =>
        {
            if (!context.Response.Headers.ContainsKey(CorrelationIdHeader))
            {
                context.Response.Headers.Append(CorrelationIdHeader, correlationId);
            }
            return Task.CompletedTask;
        });

        // Continue to next middleware
        await _next(context);
    }

    /// <summary>
    /// Extracts the correlation ID from the request header
    /// </summary>
    /// <param name="context">The HTTP context for the current request</param>
    /// <returns>The correlation ID from the header, or null if not present</returns>
    private static string? GetCorrelationIdFromHeader(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(CorrelationIdHeader, out StringValues correlationId))
        {
            return correlationId.FirstOrDefault();
        }

        return null;
    }
}
