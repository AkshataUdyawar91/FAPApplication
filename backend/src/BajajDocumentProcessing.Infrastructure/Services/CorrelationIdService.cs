using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for accessing the correlation ID for the current request
/// </summary>
/// <remarks>
/// This service retrieves the correlation ID from HttpContext.Items where it was
/// stored by the CorrelationIdMiddleware. The correlation ID is used throughout
/// the application for logging and request tracing.
/// </remarks>
public class CorrelationIdService : ICorrelationIdService
{
    private readonly IHttpContextAccessor _httpContextAccessor;
    private const string CorrelationIdKey = "CorrelationId";
    private const string FallbackCorrelationId = "no-correlation-id";

    /// <summary>
    /// Initializes a new instance of the <see cref="CorrelationIdService"/> class
    /// </summary>
    /// <param name="httpContextAccessor">Accessor for the current HTTP context</param>
    public CorrelationIdService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    /// <summary>
    /// Gets the correlation ID for the current request
    /// </summary>
    /// <returns>
    /// The correlation ID as a string, or "no-correlation-id" if not available
    /// </returns>
    /// <remarks>
    /// This method retrieves the correlation ID from HttpContext.Items. If the
    /// HttpContext is not available (e.g., in background tasks) or the correlation
    /// ID is not found, it returns a fallback value.
    /// </remarks>
    public string GetCorrelationId()
    {
        var httpContext = _httpContextAccessor.HttpContext;
        
        if (httpContext == null)
        {
            return FallbackCorrelationId;
        }

        if (httpContext.Items.TryGetValue(CorrelationIdKey, out var correlationId) && 
            correlationId is string id)
        {
            return id;
        }

        return FallbackCorrelationId;
    }
}
