using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.Infrastructure.HealthChecks;

/// <summary>
/// Health check for Firebase Cloud Messaging (FCM) credential validation.
/// Reports healthy when FCM credentials are properly configured and valid.
/// </summary>
public class FcmHealthCheck : IHealthCheck
{
    private readonly IFcmService _fcmService;
    private readonly ILogger<FcmHealthCheck> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="FcmHealthCheck"/> class
    /// </summary>
    public FcmHealthCheck(
        IFcmService fcmService,
        ILogger<FcmHealthCheck> logger)
    {
        _fcmService = fcmService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _fcmService.ValidateCredentialsAsync(cancellationToken);

            if (result.Success)
            {
                _logger.LogDebug("FCM health check passed");
                return HealthCheckResult.Healthy("FCM credentials are valid");
            }

            _logger.LogWarning("FCM health check failed: {Error}", result.ErrorMessage);
            return HealthCheckResult.Degraded(
                $"FCM credentials validation failed: {result.ErrorMessage}",
                data: new Dictionary<string, object>
                {
                    ["errorCode"] = result.ErrorCode ?? "Unknown"
                });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM health check threw an exception");
            return HealthCheckResult.Unhealthy(
                "FCM health check failed with exception",
                ex);
        }
    }
}
