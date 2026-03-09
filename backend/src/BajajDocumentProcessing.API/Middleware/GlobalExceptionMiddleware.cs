using System.Net;
using System.Text.Json;
using BajajDocumentProcessing.Application.DTOs.Common;
using BajajDocumentProcessing.Domain.Exceptions;

namespace BajajDocumentProcessing.API.Middleware;

/// <summary>
/// Global exception handling middleware that catches all unhandled exceptions
/// and returns consistent error responses to clients
/// </summary>
/// <remarks>
/// This middleware provides centralized exception handling for the entire API.
/// It maps custom domain exceptions to appropriate HTTP status codes and returns
/// typed error response DTOs. All exceptions are logged with structured data including
/// correlation ID for request tracing.
/// 
/// Exception Mapping:
/// - NotFoundException -> 404 Not Found
/// - ValidationException -> 400 Bad Request (with field-level errors)
/// - ForbiddenException -> 403 Forbidden
/// - ConflictException -> 409 Conflict
/// - All other exceptions -> 500 Internal Server Error
/// </remarks>
public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="GlobalExceptionMiddleware"/> class
    /// </summary>
    /// <param name="next">The next middleware in the pipeline</param>
    /// <param name="logger">Logger for structured exception logging</param>
    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    /// <summary>
    /// Invokes the middleware to handle the HTTP request
    /// </summary>
    /// <param name="context">The HTTP context for the current request</param>
    /// <returns>A task representing the asynchronous operation</returns>
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (NotFoundException ex)
        {
            await HandleExceptionAsync(context, ex, HttpStatusCode.NotFound);
        }
        catch (ValidationException ex)
        {
            await HandleValidationExceptionAsync(context, ex);
        }
        catch (ForbiddenException ex)
        {
            await HandleExceptionAsync(context, ex, HttpStatusCode.Forbidden);
        }
        catch (ConflictException ex)
        {
            await HandleExceptionAsync(context, ex, HttpStatusCode.Conflict);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex, HttpStatusCode.InternalServerError);
        }
    }

    /// <summary>
    /// Handles standard exceptions by creating an error response and logging the exception
    /// </summary>
    /// <param name="context">The HTTP context for the current request</param>
    /// <param name="exception">The exception that was thrown</param>
    /// <param name="statusCode">The HTTP status code to return</param>
    /// <returns>A task representing the asynchronous operation</returns>
    private async Task HandleExceptionAsync(
        HttpContext context,
        Exception exception,
        HttpStatusCode statusCode)
    {
        var correlationId = GetCorrelationId(context);

        // Log the exception with structured data
        LogException(exception, correlationId, statusCode);

        // Create error response
        var errorResponse = new ErrorResponse
        {
            CorrelationId = correlationId,
            Message = GetUserFriendlyMessage(exception, statusCode),
            StatusCode = (int)statusCode,
            Timestamp = DateTime.UtcNow
        };

        // Set response properties
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;

        // Serialize and write response
        var json = JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await context.Response.WriteAsync(json);
    }

    /// <summary>
    /// Handles validation exceptions by creating a validation error response with field-level errors
    /// </summary>
    /// <param name="context">The HTTP context for the current request</param>
    /// <param name="exception">The validation exception that was thrown</param>
    /// <returns>A task representing the asynchronous operation</returns>
    private async Task HandleValidationExceptionAsync(
        HttpContext context,
        ValidationException exception)
    {
        var correlationId = GetCorrelationId(context);

        // Log the validation exception
        _logger.LogWarning(
            exception,
            "Validation failed. CorrelationId: {CorrelationId}, Errors: {@Errors}",
            correlationId,
            exception.Errors);

        // Create validation error response
        var errorResponse = new ValidationErrorResponse
        {
            CorrelationId = correlationId,
            Message = exception.Message,
            StatusCode = (int)HttpStatusCode.BadRequest,
            Timestamp = DateTime.UtcNow,
            Errors = exception.Errors
        };

        // Set response properties
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)HttpStatusCode.BadRequest;

        // Serialize and write response
        var json = JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await context.Response.WriteAsync(json);
    }

    /// <summary>
    /// Gets the correlation ID from the HTTP context
    /// </summary>
    /// <param name="context">The HTTP context for the current request</param>
    /// <returns>The correlation ID, or a new GUID if not found</returns>
    private static string GetCorrelationId(HttpContext context)
    {
        // Try to get correlation ID from context items (set by CorrelationIdMiddleware)
        if (context.Items.TryGetValue("CorrelationId", out var correlationId) && 
            correlationId is string id)
        {
            return id;
        }

        // Try to get from request header
        if (context.Request.Headers.TryGetValue("X-Correlation-ID", out var headerValue))
        {
            return headerValue.ToString();
        }

        // Generate new correlation ID if not found
        return Guid.NewGuid().ToString();
    }

    /// <summary>
    /// Logs the exception with appropriate log level and structured data
    /// </summary>
    /// <param name="exception">The exception to log</param>
    /// <param name="correlationId">The correlation ID for request tracing</param>
    /// <param name="statusCode">The HTTP status code being returned</param>
    private void LogException(Exception exception, string correlationId, HttpStatusCode statusCode)
    {
        // Use different log levels based on exception type
        if (statusCode == HttpStatusCode.InternalServerError)
        {
            _logger.LogError(
                exception,
                "Unhandled exception occurred. CorrelationId: {CorrelationId}, StatusCode: {StatusCode}",
                correlationId,
                (int)statusCode);
        }
        else if (statusCode == HttpStatusCode.NotFound)
        {
            _logger.LogWarning(
                exception,
                "Resource not found. CorrelationId: {CorrelationId}, Message: {Message}",
                correlationId,
                exception.Message);
        }
        else if (statusCode == HttpStatusCode.Forbidden)
        {
            _logger.LogWarning(
                exception,
                "Access forbidden. CorrelationId: {CorrelationId}, Message: {Message}",
                correlationId,
                exception.Message);
        }
        else if (statusCode == HttpStatusCode.Conflict)
        {
            _logger.LogWarning(
                exception,
                "Conflict occurred. CorrelationId: {CorrelationId}, Message: {Message}",
                correlationId,
                exception.Message);
        }
        else
        {
            _logger.LogWarning(
                exception,
                "Exception occurred. CorrelationId: {CorrelationId}, StatusCode: {StatusCode}",
                correlationId,
                (int)statusCode);
        }
    }

    /// <summary>
    /// Gets a user-friendly error message based on the exception and status code
    /// </summary>
    /// <param name="exception">The exception that was thrown</param>
    /// <param name="statusCode">The HTTP status code being returned</param>
    /// <returns>A user-friendly error message</returns>
    /// <remarks>
    /// For 500 Internal Server Error, returns a generic message to avoid exposing
    /// internal implementation details. For other status codes, returns the exception message.
    /// </remarks>
    private static string GetUserFriendlyMessage(Exception exception, HttpStatusCode statusCode)
    {
        // For internal server errors, return generic message to avoid exposing internal details
        if (statusCode == HttpStatusCode.InternalServerError)
        {
            return "An unexpected error occurred while processing your request. Please contact support if the problem persists.";
        }

        // For other exceptions, return the exception message (already sanitized in custom exceptions)
        return exception.Message;
    }
}
