using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.API.Middleware;

/// <summary>
/// Middleware for logging API requests to audit log
/// </summary>
public class AuditLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<AuditLoggingMiddleware> _logger;

    public AuditLoggingMiddleware(
        RequestDelegate next,
        ILogger<AuditLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, IAuditLogService auditLogService)
    {
        // Only log authenticated requests
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var userId = context.User.FindFirst("sub")?.Value;
            var method = context.Request.Method;
            var path = context.Request.Path;
            var ipAddress = context.Connection.RemoteIpAddress?.ToString();

            // Log state-changing operations
            if (method == "POST" || method == "PUT" || method == "PATCH" || method == "DELETE")
            {
                if (Guid.TryParse(userId, out var userGuid))
                {
                    await auditLogService.LogActionAsync(
                        userGuid,
                        $"{method} {path}",
                        ipAddress: ipAddress,
                        details: $"API request: {method} {path}");
                }
            }
        }

        await _next(context);
    }
}

/// <summary>
/// Extension method for registering audit logging middleware
/// </summary>
public static class AuditLoggingMiddlewareExtensions
{
    public static IApplicationBuilder UseAuditLogging(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<AuditLoggingMiddleware>();
    }
}
